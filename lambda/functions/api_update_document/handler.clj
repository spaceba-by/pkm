(ns handler
  "API Lambda: Update an existing document (admin only)"
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [api.response :as r]
            [cheshire.core :as json]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn handler
  "Lambda handler for PUT /documents/{key+}"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)]

      ;; Check admin authorization
      (if-let [forbidden (r/require-admin event)]
        forbidden

        (let [path-params (r/parse-path-params event)
              document-key (or (:key path-params) (get path-params "key"))

              ;; Parse request body
              request-body (when-let [body (or (:body event) (get event "body"))]
                             (if (string? body)
                               (json/parse-string body true)
                               body))
              content (:content request-body)
              if-unmodified-since (:ifUnmodifiedSince request-body)]

          (println "User" user-sub "updating document:" document-key)

          (cond
            (nil? document-key)
            (r/bad-request "Missing document key")

            (nil? content)
            (r/bad-request "Missing content in request body")

            :else
            ;; Verify document exists
            (let [existing (ddb/get-item ddb-table {:PK document-key :SK "METADATA"})]
              (if (nil? existing)
                (r/not-found (str "Document not found: " document-key))

                ;; Conflict detection: check last-modified timestamp
                (let [current-modified (:modified existing)]
                  (if (and if-unmodified-since
                           current-modified
                           (pos? (compare current-modified if-unmodified-since)))
                    ;; Document was modified since the client last fetched it
                    (r/conflict "Document has been modified since your last fetch. Please reload and try again.")

                    ;; Update the document
                    (let [now (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS))]
                      ;; Update content in S3
                      (s3/put-object s3-bucket document-key content)

                      ;; Update modified timestamp in DynamoDB
                      (ddb/update-item
                        ddb-table
                        {:PK document-key :SK "METADATA"}
                        "SET modified = :m, last_edited_by = :u"
                        {":m" now
                         ":u" user-sub})

                      (println "Updated document:" document-key)
                      (r/ok-no-cache {:key document-key
                                      :modified now}))))))))))

    (catch Exception e
      (println "Error updating document:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to update document"))))
