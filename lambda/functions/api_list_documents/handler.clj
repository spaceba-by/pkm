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

(def default-timestamp "1970-01-01T00:00:00Z")

(defn format-document
  "Format document metadata for API response.
   Returns nested metadata structure matching iOS Document model.
   Defaults non-optional fields to prevent iOS decoding failures."
  [doc]
  (let [modified (or (:modified doc) default-timestamp)
        created (or (:created doc) modified)]
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
