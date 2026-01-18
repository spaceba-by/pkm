(ns aws.dynamodb
  "DynamoDB operations using awyeah client"
  (:require [com.grzm.awyeah.client.api :as aws]
            [clojure.walk :as walk]
            [clojure.string :as str]))

(defonce ^:private ddb-client
  (delay (aws/client {:api :dynamodb})))

(defn- check-error
  "Check AWS response for errors and throw if found"
  [response operation]
  (when-let [error-category (:cognitect.anomalies/category response)]
    (throw (ex-info (str "DynamoDB " operation " failed: "
                         (or (:message response) error-category))
                    {:operation operation
                     :error-category error-category
                     :error-code (:cognitect.aws.error/code response)
                     :response response})))
  response)

(defn- marshall-value
  "Converts Clojure value to DynamoDB attribute value format"
  [v]
  (cond
    (string? v) {:S v}
    (number? v) {:N (str v)}
    (boolean? v) {:BOOL v}
    (nil? v) {:NULL true}
    ;; Handle any sequential collection (vector, list, lazy-seq)
    (sequential? v) {:L (mapv marshall-value v)}
    (set? v) (cond
               (every? string? v) {:SS (vec v)}
               (every? number? v) {:NS (mapv str v)}
               :else {:L (mapv marshall-value (vec v))})
    (map? v) {:M (walk/postwalk
                   (fn [x]
                     (if (and (map? x) (not (contains? x :S)))
                       (into {} (map (fn [[k v]] [k (marshall-value v)]) x))
                       x))
                   v)}
    :else {:S (str v)}))

(defn- marshall-item
  "Converts Clojure map to DynamoDB item format"
  [item]
  (into {}
        (map (fn [[k v]]
               [(name k) (marshall-value v)])
             item)))

(defn- unmarshall-value
  "Converts DynamoDB attribute value to Clojure value"
  [attr-value]
  (cond
    (:S attr-value) (:S attr-value)
    (:N attr-value) (if (re-find #"\." (:N attr-value))
                      (Double/parseDouble (:N attr-value))
                      (Long/parseLong (:N attr-value)))
    (:BOOL attr-value) (:BOOL attr-value)
    (:NULL attr-value) nil
    (:L attr-value) (mapv unmarshall-value (:L attr-value))
    (:SS attr-value) (set (:SS attr-value))
    (:NS attr-value) (set (map #(Long/parseLong %) (:NS attr-value)))
    (:M attr-value) (into {}
                          (map (fn [[k v]]
                                 [(keyword k) (unmarshall-value v)])
                               (:M attr-value)))
    :else nil))

(defn- unmarshall-item
  "Converts DynamoDB item to Clojure map"
  [ddb-item]
  (into {}
        (map (fn [[k v]]
               [(keyword k) (unmarshall-value v)])
             ddb-item)))

(defn put-item
  "Writes item to DynamoDB table"
  [table-name item]
  (-> (aws/invoke @ddb-client
                  {:op :PutItem
                   :request {:TableName table-name
                            :Item (marshall-item item)}})
      (check-error "PutItem")))

(defn get-item
  "Retrieves item from DynamoDB table by key"
  [table-name key]
  (let [response (-> (aws/invoke @ddb-client
                                 {:op :GetItem
                                  :request {:TableName table-name
                                           :Key (marshall-item key)}})
                     (check-error "GetItem"))]
    (when-let [item (:Item response)]
      (unmarshall-item item))))

(defn delete-item
  "Deletes item from DynamoDB table"
  [table-name key]
  (-> (aws/invoke @ddb-client
                  {:op :DeleteItem
                   :request {:TableName table-name
                            :Key (marshall-item key)}})
      (check-error "DeleteItem")))

(defn query
  "Queries DynamoDB table with key condition"
  [table-name & {:keys [index-name key-condition-expr expr-attr-values limit]
                 :or {limit 100}}]
  (let [request (cond-> {:TableName table-name
                         :KeyConditionExpression key-condition-expr
                         :ExpressionAttributeValues (marshall-item expr-attr-values)
                         :Limit limit}
                  index-name (assoc :IndexName index-name))
        response (-> (aws/invoke @ddb-client
                                 {:op :Query
                                  :request request})
                     (check-error "Query"))]
    (mapv unmarshall-item (:Items response))))

(defn scan
  "Scans DynamoDB table with optional filter"
  [table-name & {:keys [filter-expr expr-attr-values limit]
                 :or {limit 100}}]
  (let [request (cond-> {:TableName table-name
                         :Limit limit}
                  filter-expr (assoc :FilterExpression filter-expr)
                  expr-attr-values (assoc :ExpressionAttributeValues
                                         (marshall-item expr-attr-values)))
        response (-> (aws/invoke @ddb-client
                                 {:op :Scan
                                  :request request})
                     (check-error "Scan"))]
    (mapv unmarshall-item (:Items response))))

(defn update-item
  "Updates item in DynamoDB table"
  [table-name key update-expr expr-attr-values]
  (let [response (-> (aws/invoke @ddb-client
                                 {:op :UpdateItem
                                  :request {:TableName table-name
                                           :Key (marshall-item key)
                                           :UpdateExpression update-expr
                                           :ExpressionAttributeValues (marshall-item expr-attr-values)
                                           :ReturnValues "ALL_NEW"}})
                     (check-error "UpdateItem"))]
    (when-let [attrs (:Attributes response)]
      (unmarshall-item attrs))))

(defn query-by-classification
  "Queries documents by classification type"
  [table-name classification]
  (query table-name
         :index-name "ClassificationIndex"
         :key-condition-expr "classification = :class"
         :expr-attr-values {":class" classification}))

(defn query-by-tag
  "Queries documents by tag"
  [table-name tag]
  (query table-name
         :key-condition-expr "PK = :pk"
         :expr-attr-values {":pk" (str "TAG#" tag)}))

(defn query-recent-documents
  "Queries recently modified documents"
  [table-name since-timestamp]
  (scan table-name
        :filter-expr "last_modified > :since"
        :expr-attr-values {":since" since-timestamp}))

(defn get-all-classifications
  "Get all documents grouped by classification type.
   Returns map of classification -> vector of document paths"
  [table-name]
  (let [valid-types ["meeting" "idea" "reference" "journal" "project"]
        classifications (into {}
                             (for [classification valid-types]
                               (let [docs (query-by-classification table-name classification)
                                     doc-paths (mapv :document_path docs)]
                                 [classification (vec (sort doc-paths))])))]
    (println "Retrieved all classifications")
    classifications))

(defn store-entities
  "Store extracted entities for a document"
  [table-name file-path entities]
  (let [now (str (java.time.Instant/now))]
    ;; Update document metadata with entities
    (update-item table-name
                 {:PK file-path :SK "METADATA"}
                 "SET entities = :e, modified = :m"
                 {":e" entities
                  ":m" now})

    ;; Create entity index entries
    (doseq [[entity-type entity-list] entities
            entity-name entity-list]
      (let [entity-key (str "entity#" (name entity-type) "#" (str/lower-case entity-name))]
        (put-item table-name
                  {:PK entity-key
                   :SK (str "doc#" file-path)
                   :entity_key entity-key
                   :entity_type (name entity-type)
                   :entity_name entity-name
                   :document_path file-path
                   :modified now})))

    (println "Stored entities for" file-path)))

(defn get-entity-mentions
  "Get all documents that mention a specific entity"
  [table-name entity-type entity-name]
  (let [entity-key (str "entity#" entity-type "#" (str/lower-case entity-name))
        results (query table-name
                      :key-condition-expr "PK = :ek"
                      :expr-attr-values {":ek" entity-key})]
    (mapv :document_path results)))

(defn get-documents-modified-since
  "Get documents modified since a given ISO timestamp"
  [table-name since-iso & {:keys [limit] :or {limit 1000}}]
  (let [response (-> (aws/invoke @ddb-client
                                 {:op :Scan
                                  :request {:TableName table-name
                                           :FilterExpression "begins_with(PK, :prefix) AND SK = :sk AND modified >= :since"
                                           :ExpressionAttributeValues (marshall-item
                                                                       {":prefix" "doc#"
                                                                        ":sk" "METADATA"
                                                                        ":since" since-iso})
                                           :Limit limit}})
                     (check-error "Scan"))]
    (println "Found" (count (:Items response)) "documents modified since" since-iso)
    (mapv unmarshall-item (:Items response))))
