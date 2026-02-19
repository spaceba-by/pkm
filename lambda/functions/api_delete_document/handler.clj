(ns handler
  "API Lambda: Delete a document (admin only).
   Deletes the S3 object. DynamoDB cleanup happens automatically
   via the delete_document EventBridge handler."
  (:require [aws.s3 :as s3]
            [api.response :as r]
            [cheshire.core :as json]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))

(defn handler
  "Lambda handler for DELETE /documents/{key+}"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)]

      ;; Check admin authorization
      (if-let [forbidden (r/require-admin event)]
        forbidden

        (let [path-params (r/parse-path-params event)
              document-key (or (:key path-params) (get path-params "key"))]

          (println "User" user-sub "deleting document:" document-key)

          (cond
            (nil? document-key)
            (r/bad-request "Missing document key")

            ;; Prevent deleting agent outputs
            (.startsWith document-key "_agent/")
            (r/bad-request "Cannot delete agent-generated documents")

            :else
            ;; Check if document exists
            (if-not (s3/object-exists? s3-bucket document-key)
              (r/not-found (str "Document not found: " document-key))

              ;; Delete from S3 - EventBridge will trigger DynamoDB cleanup
              (do
                (s3/delete-object s3-bucket document-key)
                (println "Deleted document:" document-key)
                (r/ok-no-cache {:key document-key
                                :deleted true})))))))

    (catch Exception e
      (println "Error deleting document:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to delete document"))))
