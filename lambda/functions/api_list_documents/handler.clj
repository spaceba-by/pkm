(ns handler
  "API Lambda: List documents with pagination and filtering"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def default-limit 50)
(def max-limit 100)

(defn list-all-documents
  "Scan all document metadata items"
  [limit]
  (ddb/scan ddb-table
            :filter-expr "SK = :sk"
            :expr-attr-values {":sk" "METADATA"}
            :limit (min limit max-limit)))

(defn list-by-classification
  "Query documents by classification using GSI"
  [classification limit]
  (ddb/query ddb-table
             :index-name "classification-index"
             :key-condition-expr "classification = :class"
             :expr-attr-values {":class" classification}
             :limit (min limit max-limit)))

(defn format-document
  "Format document metadata for API response"
  [doc]
  {:id (:PK doc)
   :title (or (:title doc) "Untitled")
   :classification (:classification doc)
   :tags (or (:tags doc) [])
   :linksTo (or (:links_to doc) [])
   :entities (:entities doc)
   :created (:created doc)
   :modified (:modified doc)
   :hasFrontmatter (:has_frontmatter doc)})

(defn handler
  "Lambda handler for GET /documents"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          params (r/parse-query-params event)
          classification (or (get params :classification)
                             (get params "classification"))
          limit (r/parse-int-param params "limit" default-limit)
          user-sub (r/get-user-sub event)

          _ (println "User" user-sub "listing documents, classification:" classification "limit:" limit)

          documents (if classification
                      (list-by-classification classification limit)
                      (list-all-documents limit))
          formatted (mapv format-document documents)]

      (r/ok {:documents formatted
             :count (count formatted)
             :nextCursor nil}))

    (catch Exception e
      (println "Error listing documents:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to list documents"))))
