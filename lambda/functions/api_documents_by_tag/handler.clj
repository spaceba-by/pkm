(ns handler
  "API Lambda: Get documents by tag"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def default-limit 50)
(def max-limit 100)

(defn get-tag-entries
  "Get all tag index entries for a specific tag"
  [tag limit]
  (ddb/query ddb-table
             :key-condition-expr "PK = :pk"
             :expr-attr-values {":pk" (str "tag#" tag)}
             :limit (min limit max-limit)))

(defn get-document-metadata
  "Get full metadata for a document.
   TODO: This creates an N+1 query pattern - one query per document.
   For better performance with large result sets, consider using
   DynamoDB BatchGetItem to fetch multiple documents in a single request."
  [doc-path]
  (ddb/get-item ddb-table {:PK doc-path :SK "METADATA"}))

(defn format-document
  "Format document for response.
   Returns nested metadata structure matching iOS Document model."
  [metadata]
  {:id (:PK metadata)
   :title (or (:title metadata) "Untitled")
   :metadata {:classification (:classification metadata)
              :tags (or (:tags metadata) [])
              :linksTo (or (:links_to metadata) [])
              :entities (:entities metadata)
              :created (:created metadata)
              :modified (:modified metadata)
              :hasFrontmatter (:has_frontmatter metadata)}})

(defn handler
  "Lambda handler for GET /tags/{tag}/documents"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          path-params (r/parse-path-params event)
          tag (or (get path-params :tag) (get path-params "tag"))
          params (r/parse-query-params event)
          limit (r/parse-int-param params "limit" default-limit)
          user-sub (r/get-user-sub event)]

      (when-not tag
        (throw (ex-info "Missing tag parameter" {:type :bad-request})))

      (println "User" user-sub "getting documents for tag:" tag)

      (let [tag-entries (get-tag-entries tag limit)
            ;; Get full metadata for each document
            documents (for [entry tag-entries
                           :let [doc-path (:document_path entry)
                                 metadata (when doc-path (get-document-metadata doc-path))]
                           :when metadata]
                       (format-document metadata))]

        (r/ok {:tag tag
               :documents (vec documents)
               :count (count documents)})))

    (catch clojure.lang.ExceptionInfo e
      (let [data (ex-data e)]
        (case (:type data)
          :bad-request (r/bad-request (.getMessage e))
          (do
            (println "Error:" (.getMessage e))
            (r/internal-error "Failed to get documents by tag")))))

    (catch Exception e
      (println "Error getting documents by tag:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to get documents by tag"))))
