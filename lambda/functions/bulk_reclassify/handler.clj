(ns handler
  "Lambda function for bulk reclassification of documents"
  (:require [aws.dynamodb :as ddb]
            [aws.lambda :as lambda]
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
          params (or event {})
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
        (do
          (doseq [doc eligible]
            (let [s3-key (or (:s3_key doc) (:document_path doc) (:PK doc))]
              (when (and s3-key classify-lambda)
                (println "Triggering reclassification for:" s3-key)
                (lambda/invoke-async
                  classify-lambda
                  {:detail {:bucket {:name (System/getenv "S3_BUCKET_NAME")}
                            :object {:key s3-key}}}))))

          {:statusCode 200
           :body (json/generate-string
                  {:dry_run false
                   :triggered eligible-count
                   :skipped_override (count (filter :classification_override all-docs))
                   :classification_filter classification})})))

    (catch Exception e
      (println "Error in bulk reclassify:" (.getMessage e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:error (.getMessage e)})})))

;; For local testing
(defn -main [& args]
  (println "Running bulk reclassify")
  (println "Result:" (handler {:body "{}"})))
