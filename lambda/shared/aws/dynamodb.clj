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
  "Queries DynamoDB table with key condition.
   Options:
     :index-name - Name of GSI to query
     :key-condition-expr - Key condition expression
     :expr-attr-values - Expression attribute values map
     :limit - Maximum items to return (default 100)
     :select - Select mode: nil (default), \"COUNT\", \"ALL_ATTRIBUTES\", etc.
               When \"COUNT\", returns just the count (integer) instead of items."
  [table-name & {:keys [index-name key-condition-expr expr-attr-values limit select]
                 :or {limit 100}}]
  (let [request (cond-> {:TableName table-name
                         :KeyConditionExpression key-condition-expr
                         :ExpressionAttributeValues (marshall-item expr-attr-values)}
                  ;; Don't include Limit when using COUNT - we want total count
                  (and limit (not= select "COUNT")) (assoc :Limit limit)
                  index-name (assoc :IndexName index-name)
                  select (assoc :Select select))
        response (-> (aws/invoke @ddb-client
                                 {:op :Query
                                  :request request})
                     (check-error "Query"))]
    ;; When SELECT COUNT is used, return just the count
    (if (= select "COUNT")
      (:Count response)
      (mapv unmarshall-item (:Items response)))))

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

(defn scan-all
  "Scans entire DynamoDB table with pagination, handling LastEvaluatedKey.
   Returns all matching items across all pages."
  [table-name & {:keys [filter-expr expr-attr-values]}]
  (loop [acc []
         exclusive-start-key nil]
    (let [request (cond-> {:TableName table-name}
                    filter-expr (assoc :FilterExpression filter-expr)
                    expr-attr-values (assoc :ExpressionAttributeValues
                                           (marshall-item expr-attr-values))
                    exclusive-start-key (assoc :ExclusiveStartKey
                                              (marshall-item exclusive-start-key)))
          response (-> (aws/invoke @ddb-client
                                   {:op :Scan
                                    :request request})
                       (check-error "Scan"))
          items (mapv unmarshall-item (:Items response))
          new-acc (into acc items)
          last-key (when-let [lek (:LastEvaluatedKey response)]
                     (unmarshall-item lek))]
      (if last-key
        (recur new-acc last-key)
        new-acc))))

(defn query-all
  "Queries DynamoDB table with pagination, handling LastEvaluatedKey.
   Returns all matching items across all pages.
   Options:
     :index-name - Name of GSI to query
     :key-condition-expr - Key condition expression
     :expr-attr-values - Expression attribute values map"
  [table-name & {:keys [index-name key-condition-expr expr-attr-values]}]
  (loop [acc []
         exclusive-start-key nil]
    (let [request (cond-> {:TableName table-name
                           :KeyConditionExpression key-condition-expr
                           :ExpressionAttributeValues (marshall-item expr-attr-values)}
                    index-name (assoc :IndexName index-name)
                    exclusive-start-key (assoc :ExclusiveStartKey
                                              (marshall-item exclusive-start-key)))
          response (-> (aws/invoke @ddb-client
                                   {:op :Query
                                    :request request})
                       (check-error "Query"))
          items (mapv unmarshall-item (:Items response))
          new-acc (into acc items)
          last-key (when-let [lek (:LastEvaluatedKey response)]
                     (unmarshall-item lek))]
      (if last-key
        (recur new-acc last-key)
        new-acc))))

(defn update-item
  "Updates item in DynamoDB table.
   Optional :expr-attr-names for ExpressionAttributeNames (avoids reserved word conflicts)."
  [table-name key update-expr expr-attr-values & {:keys [expr-attr-names]}]
  (let [request (cond-> {:TableName table-name
                         :Key (marshall-item key)
                         :UpdateExpression update-expr
                         :ExpressionAttributeValues (marshall-item expr-attr-values)
                         :ReturnValues "ALL_NEW"}
                  expr-attr-names (assoc :ExpressionAttributeNames expr-attr-names))
        response (-> (aws/invoke @ddb-client
                                 {:op :UpdateItem
                                  :request request})
                     (check-error "UpdateItem"))]
    (when-let [attrs (:Attributes response)]
      (unmarshall-item attrs))))

(defn update-item-attrs
  "Updates specific attributes of an item from a map of field->value.
   Only sets the given fields, leaving other attributes untouched.
   Uses ExpressionAttributeNames to avoid DynamoDB reserved word conflicts."
  [table-name key attrs]
  (if (empty? attrs)
    (throw (ex-info "update-item-attrs called with empty attrs; no attributes to update"
                    {:table-name table-name
                     :key key}))
    (let [indexed-fields (map-indexed vector attrs)
          set-clauses (map (fn [[i _]] (str "#n" i " = :v" i)) indexed-fields)
          update-expr (str "SET " (str/join ", " set-clauses))
          attr-names (into {} (map (fn [[i [k _]]] [(str "#n" i) (name k)]) indexed-fields))
          attr-values (into {} (map (fn [[i [_ v]]] [(str ":v" i) v]) indexed-fields))]
      (update-item table-name key update-expr attr-values :expr-attr-names attr-names))))

(defn query-by-classification
  "Queries all documents by classification type with full pagination"
  [table-name classification]
  (query-all table-name
             :index-name "classification-index"
             :key-condition-expr "classification = :class"
             :expr-attr-values {":class" classification}))

(defn query-by-tag
  "Queries documents by tag"
  [table-name tag]
  (query table-name
         :key-condition-expr "PK = :pk"
         :expr-attr-values {":pk" (str "tag#" tag)}))

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
  (let [now (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS))]
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
  (let [entity-key (str "entity#" (name entity-type) "#" (str/lower-case entity-name))
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
                                           :FilterExpression "SK = :sk AND modified >= :since"
                                           :ExpressionAttributeValues (marshall-item
                                                                       {":sk" "METADATA"
                                                                        ":since" since-iso})
                                           :Limit limit}})
                     (check-error "Scan"))]
    (println "Found" (count (:Items response)) "documents modified since" since-iso)
    (mapv unmarshall-item (:Items response))))
