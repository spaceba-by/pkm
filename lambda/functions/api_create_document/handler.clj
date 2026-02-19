(ns handler
  "API Lambda: Create a new document (admin only)"
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn validate-key
  "Validate the document key. Must end in .md and not start with _ or ."
  [key]
  (cond
    (str/blank? key)
    "Document key is required"

    (not (str/ends-with? key ".md"))
    "Document key must end with .md"

    (str/starts-with? key "_")
    "Document key must not start with _"

    (str/starts-with? key ".")
    "Document key must not start with ."

    (re-find #"\.\." key)
    "Document key must not contain .."

    :else nil))

(defn handler
  "Lambda handler for POST /documents"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)]

      ;; Check admin authorization
      (if-let [forbidden (r/require-admin event)]
        forbidden

        (let [;; Parse request body
              request-body (when-let [body (or (:body event) (get event "body"))]
                             (if (string? body)
                               (json/parse-string body true)
                               body))
              document-key (:key request-body)
              content (or (:content request-body) "")
              title (:title request-body)]

          (println "User" user-sub "creating document:" document-key)

          ;; Validate inputs
          (if-let [error (validate-key document-key)]
            (r/bad-request error)

            ;; Check if document already exists (S3 or DynamoDB metadata)
            (if (or (s3/object-exists? s3-bucket document-key)
                    (ddb/get-item ddb-table {:PK document-key :SK "METADATA"}))
              (r/conflict (str "Document already exists: " document-key))

              ;; Create document in S3
              (let [now (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS))]
                (s3/put-object s3-bucket document-key content)

                ;; Create initial metadata in DynamoDB
                (ddb/put-item ddb-table
                              {:PK document-key
                               :SK "METADATA"
                               :title (or title (last (str/split document-key #"/")))
                               :classification "reference"
                               :tags []
                               :links_to []
                               :has_frontmatter false
                               :created now
                               :modified now
                               :created_by user-sub})

                (println "Created document:" document-key)
                (r/created {:key document-key
                            :title (or title (last (str/split document-key #"/")))
                            :created_at now})))))))

    (catch Exception e
      (println "Error creating document:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to create document"))))
