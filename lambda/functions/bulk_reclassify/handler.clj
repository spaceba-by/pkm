(ns handler
  "Lambda function for bulk reclassification of documents"
  (:require [aws.dynamodb :as ddb]
            [aws.lambda :as lambda]
            [aws.s3 :as s3]
            [shared.deletion :as deletion]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def classify-lambda (System/getenv "CLASSIFY_DOCUMENT_LAMBDA"))

(defn get-all-metadata-items
  "Scan for all METADATA items in DynamoDB.
   Uses paginated scan to handle large vaults."
  [table-name]
  (ddb/scan-all table-name
               :filter-expr "SK = :sk"
               :expr-attr-values {":sk" "METADATA"}))

(defn should-reclassify?
  "Check if a document should be reclassified based on filters"
  [doc {:keys [classification dry_run]}]
  (and
   ;; Skip documents with override set
   (not (:classification_override doc))
   ;; If classification filter provided, only include matching docs
   (or (nil? classification)
       (= classification (:classification doc)))))

(defn handler
  "Lambda handler for bulk reclassification.
   Accepts JSON body with:
   - classification: optional filter by current classification
   - dry_run: if true, return count without reclassifying"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          ;; Support both direct invocation (params at top level) and
          ;; API-style invocation (params nested in :body as JSON string)
          params (if-let [body (:body event)]
                   (if (string? body)
                     (json/parse-string body true)
                     body)
                   (or event {}))
          classification (:classification params)
          dry-run (boolean (:dry_run params))

          _ (println "Bulk reclassify - classification filter:" classification
                     "dry_run:" dry-run)

          ;; Get all documents
          all-docs (get-all-metadata-items ddb-table)
          _ (println "Found" (count all-docs) "total documents")

          ;; Filter to eligible documents
          eligible (filter #(should-reclassify? % params) all-docs)
          eligible-count (count eligible)

          _ (println "Eligible for reclassification:" eligible-count)]

      (if dry-run
        ;; Dry run - just return counts
        {:statusCode 200
         :body (json/generate-string
                {:dry_run true
                 :total_documents (count all-docs)
                 :eligible_documents eligible-count
                 :skipped_override (count (filter :classification_override all-docs))
                 :classification_filter classification})}

        ;; Actually reclassify - invoke classify_document for each
        (let [bucket-name (System/getenv "S3_BUCKET_NAME")
              triggered (atom 0)
              skipped-missing (atom 0)]
          (doseq [doc eligible]
            (let [s3-key (or (:s3_key doc) (:document_path doc) (:PK doc))]
              (when (and s3-key classify-lambda)
                (if (s3/object-exists? bucket-name s3-key)
                  (do
                    (println "Triggering reclassification for:" s3-key)
                    (lambda/invoke-async
                      classify-lambda
                      {:detail {:bucket {:name bucket-name}
                                :object {:key s3-key}}})
                    (swap! triggered inc)
                    ;; Throttle to avoid overwhelming Bedrock rate limits
                    (Thread/sleep 200))
                  (do
                    (println "Cleaning up stale DynamoDB records for missing S3 object:" s3-key)
                    (try
                      (deletion/cascade-delete-document ddb-table s3-key)
                      (catch Exception e
                        (println "Error cleaning up stale records for" s3-key ":" (ex-message e))))
                    (swap! skipped-missing inc))))))

          {:statusCode 200
           :body (json/generate-string
                  {:dry_run false
                   :triggered @triggered
                   :skipped_missing @skipped-missing
                   :skipped_override (count (filter :classification_override all-docs))
                   :classification_filter classification})})))

    (catch Exception e
      (println "Error in bulk reclassify:" (ex-message e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:error (ex-message e)})})))

;; For local testing
(defn -main []
  (println "Running bulk reclassify")
  (println "Result:" (handler {:body "{}"})))
