(ns handler
  "API Lambda: Get single document with content"
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [api.response :as r]
            [cheshire.core :as json]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn get-document-metadata
  "Get document metadata from DynamoDB"
  [document-key]
  (ddb/get-item ddb-table {:PK document-key :SK "METADATA"}))

(defn get-document-content
  "Get document content from S3"
  [document-key]
  (try
    (s3/get-object s3-bucket document-key)
    (catch Exception e
      (println "Error fetching content for" document-key ":" (ex-message e))
      nil)))

(def default-timestamp "1970-01-01T00:00:00Z")

(defn format-document-detail
  "Format full document with content for API response.
   Returns nested metadata structure matching iOS Document model.
   Defaults non-optional fields to prevent iOS decoding failures."
  [metadata content]
  (let [modified (r/truncate-timestamp (or (:modified metadata) default-timestamp))
        created (r/truncate-timestamp (or (:created metadata) modified))]
    {:id (:PK metadata)
     :title (or (:title metadata) "Untitled")
     :content content
     :metadata {:classification (or (:classification metadata) "reference")
                :tags (or (:tags metadata) [])
                :linksTo (or (:links_to metadata) [])
                :entities (:entities metadata)
                :created created
                :modified modified
                :hasFrontmatter (if (some? (:has_frontmatter metadata))
                                  (:has_frontmatter metadata)
                                  false)}}))

(defn handler
  "Lambda handler for GET /documents/{key+}"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          path-params (r/parse-path-params event)
          document-key (or (get path-params :key)
                           (get path-params "key"))
          user-sub (r/get-user-sub event)]

      (when-not document-key
        (throw (ex-info "Missing document key" {:type :bad-request})))

      (println "User" user-sub "fetching document:" document-key)

      (let [metadata (get-document-metadata document-key)]
        (if metadata
          ;; Document has DynamoDB metadata — standard path
          (let [content (get-document-content document-key)
                document (format-document-detail metadata content)]
            (r/ok document))

          ;; No DynamoDB metadata — try S3 directly (agent outputs like summaries/reports)
          (let [content (get-document-content document-key)]
            (if content
              (let [document (format-document-detail {:PK document-key} content)]
                (r/ok document))
              (r/not-found (str "Document not found: " document-key)))))))

    (catch clojure.lang.ExceptionInfo e
      (let [data (ex-data e)]
        (case (:type data)
          :bad-request (r/bad-request (ex-message e))
          (do
            (println "Error:" (ex-message e))
            (r/internal-error "Failed to get document")))))

    (catch Exception e
      (println "Error getting document:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to get document"))))
