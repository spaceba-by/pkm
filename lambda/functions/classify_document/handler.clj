(ns handler
  "Lambda function to classify markdown documents using Bedrock"
  (:require [aws.s3 :as s3]
            [aws.dynamodb :as ddb]
            [aws.bedrock :as bedrock]
            [markdown.utils :as md]
            [cheshire.core :as json]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def bedrock-model (System/getenv "BEDROCK_MODEL_ID"))

(defn should-skip?
  "Check if file should be skipped"
  [object-key]
  (or
   ;; Skip non-markdown files
   (not (.endsWith object-key ".md"))
   ;; Skip _agent directory
   (.startsWith object-key "_agent/")
   (re-find #"/_agent/" object-key)
   ;; Skip .obsidian directory
   (.startsWith object-key ".obsidian/")
   (re-find #"/\.obsidian/" object-key)))

(defn classify-document
  "Classify a markdown document using Bedrock"
  [bucket-name object-key]
  (println "Processing document:" object-key)

  ;; Check for classification override before reclassifying
  (let [existing (ddb/get-item ddb-table {:PK object-key :SK "METADATA"})]
    (when (:classification_override existing)
      (println "Skipping" object-key "- classification override is set")
      (throw (ex-info "Classification override set"
                      {:object-key object-key
                       :classification (:classification existing)
                       :skipped true}))))

  ;; Get document content
  (let [content (s3/get-object bucket-name object-key)]

    (when (empty? content)
      (println "Warning: Empty content for" object-key)
      (throw (ex-info "Empty document" {:object-key object-key})))

    ;; Parse metadata
    (let [metadata (md/parse-markdown-metadata content)

          ;; Classify document using Bedrock
          result (bedrock/classify-document bedrock-model content metadata)
          classification (:classification result)
          confidence (:confidence result)

          _ (println "Classified" object-key "as:" classification
                     "confidence:" confidence)

          ;; Add classification, confidence, and timestamp to metadata
          metadata (assoc metadata
                         :classification classification
                         :classification_confidence confidence
                         :modified (str (java.time.Instant/now))
                         :s3_key object-key)]

      ;; Store classification in DynamoDB
      (ddb/put-item ddb-table
                    (assoc metadata
                           :PK object-key
                           :SK "METADATA"
                           :document_path object-key))

      {:classification classification
       :confidence confidence
       :title (:title metadata)})))

(defn handler
  "Lambda handler for bblf runtime - receives raw HTTP request from Lambda Runtime API"
  [request]
  (try
    ;; bblf.runtime passes the raw HTTP response from Lambda Runtime API
    (let [event (json/parse-string (:body request) true)]
      (println "Received event:" (json/generate-string event))

      ;; Extract S3 object details from EventBridge event
      (let [detail (get event :detail {})
            bucket-name (get-in detail [:bucket :name])
            object-key (get-in detail [:object :key])]

        ;; Validate event
        (when (or (nil? bucket-name) (nil? object-key))
          (println "Error: Missing bucket name or object key in event")
          (throw (ex-info "Invalid event format" {:event event})))

        ;; Check if should skip
        (if (should-skip? object-key)
          (do
            (println "Skipping file:" object-key)
            {:statusCode 200
             :body (json/generate-string {:message "Skipped file"
                                          :object-key object-key})})

          ;; Classify the document
          (let [result (classify-document bucket-name object-key)]
            {:statusCode 200
             :body (json/generate-string {:document object-key
                                          :classification (:classification result)
                                          :confidence (:confidence result)})}))))

    (catch Exception e
      (if (:skipped (ex-data e))
        ;; Override skip is not an error
        {:statusCode 200
         :body (json/generate-string {:document (get (ex-data e) :object-key)
                                      :classification (get (ex-data e) :classification)
                                      :skipped true})}
        (do
          (println "Error processing document:" (.getMessage e))
          (.printStackTrace e)
          {:statusCode 500
           :body (json/generate-string {:error (.getMessage e)})})))))

;; For local testing
(defn -main [& args]
  (let [test-event {:detail {:bucket {:name s3-bucket}
                             :object {:key "test.md"}}}]
    (println "Running test with event:" test-event)
    (println "Result:" (handler test-event))))


(comment 
  (-main))
