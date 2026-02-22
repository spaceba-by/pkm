(ns handler
  "API Lambda: List documents with pagination and filtering"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json])
  (:import [java.util Base64]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def default-limit 50)
(def max-limit 100)

(defn encode-cursor
  "Encode a DynamoDB LastEvaluatedKey as a base64 JSON string"
  [last-key]
  (when last-key
    (.encodeToString (Base64/getUrlEncoder)
                     (.getBytes (json/generate-string last-key) "UTF-8"))))

(defn decode-cursor
  "Decode a base64 JSON cursor back to a DynamoDB ExclusiveStartKey map"
  [cursor]
  (when (and cursor (not (empty? cursor)))
    (try
      (let [decoded (String. (.decode (Base64/getUrlDecoder) cursor) "UTF-8")]
        (json/parse-string decoded true))
      (catch Exception _
        nil))))

(def sort-index
  "Map sort parameter to GSI name.
   Note: all-documents-created-index only includes items that have a 'created'
   attribute. Items missing 'created' are not projected into the GSI."
  {"modified" "all-documents-modified-index"
   "created"  "all-documents-created-index"})

(defn list-all-documents
  "Query all document metadata items using a GSI, ordered by date descending.
   Uses the sort param to select the appropriate GSI (modified or created)."
  [limit cursor sort]
  (let [start-key (decode-cursor cursor)
        index-name (get sort-index (or sort "modified") "all-documents-modified-index")
        [items last-key] (ddb/query-to-limit ddb-table
                                             :index-name index-name
                                             :key-condition-expr "SK = :sk"
                                             :expr-attr-values {":sk" "METADATA"}
                                             :limit (min limit max-limit)
                                             :scan-index-forward false
                                             :exclusive-start-key start-key)]
    [items (encode-cursor last-key)]))

(defn list-by-classification
  "Query documents by classification using GSI, ordered by modified date descending.
   Note: classification-index only supports modified as range key. The sort param
   is ignored here; client-side re-sort handles created ordering for filtered results."
  [classification limit cursor]
  (let [start-key (decode-cursor cursor)
        [items last-key] (ddb/query-to-limit ddb-table
                                             :index-name "classification-index"
                                             :key-condition-expr "classification = :class"
                                             :expr-attr-values {":class" classification}
                                             :limit (min limit max-limit)
                                             :scan-index-forward false
                                             :exclusive-start-key start-key)]
    [items (encode-cursor last-key)]))

(def default-timestamp "1970-01-01T00:00:00Z")

(defn format-document
  "Format document metadata for API response.
   Returns nested metadata structure matching iOS Document model.
   Defaults non-optional fields to prevent iOS decoding failures."
  [doc]
  (let [modified (r/truncate-timestamp (or (:modified doc) default-timestamp))
        created (r/truncate-timestamp (or (:created doc) modified))]
    {:id (:PK doc)
     :title (or (:title doc) "Untitled")
     :metadata {:classification (or (:classification doc) "reference")
                :tags (or (:tags doc) [])
                :linksTo (or (:links_to doc) [])
                :entities (:entities doc)
                :created created
                :modified modified
                :hasFrontmatter (if (some? (:has_frontmatter doc))
                                  (:has_frontmatter doc)
                                  false)}}))

(defn handler
  "Lambda handler for GET /documents"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          params (r/parse-query-params event)
          classification (or (get params :classification)
                             (get params "classification"))
          limit (r/parse-int-param params "limit" default-limit)
          cursor (or (get params :cursor)
                     (get params "cursor"))
          sort (or (get params :sort)
                   (get params "sort"))
          user-sub (r/get-user-sub event)

          _ (println "User" user-sub "listing documents, classification:" classification "limit:" limit "sort:" sort)

          [documents next-cursor] (if classification
                                    (list-by-classification classification limit cursor)
                                    (list-all-documents limit cursor sort))
          formatted (mapv format-document documents)]

      (r/ok {:documents formatted
             :count (count formatted)
             :nextCursor next-cursor}))

    (catch Exception e
      (println "Error listing documents:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to list documents"))))
