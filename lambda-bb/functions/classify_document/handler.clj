(ns classify-document.handler
  "Lambda function to classify markdown documents using Bedrock"
  (:require [aws.s3 :as s3]
            [aws.dynamodb :as ddb]
            [aws.lambda :as lambda]
            [aws.bedrock :as bedrock]
            [markdown.utils :as md]
            [clojure.data.json :as json]
            [java-time.api :as time]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def bedrock-model (System/getenv "BEDROCK_MODEL_ID"))
(def update-index-lambda (System/getenv "UPDATE_INDEX_LAMBDA"))

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

  ;; Get document content
  (let [content (s3/get-object bucket-name object-key)]

    (when (empty? content)
      (println "Warning: Empty content for" object-key)
      (throw (ex-info "Empty document" {:object-key object-key})))

    ;; Parse metadata
    (let [metadata (md/parse-markdown-metadata content)

          ;; Classify document using Bedrock
          classification (bedrock/classify-document bedrock-model content metadata)

          _ (println "Classified" object-key "as:" classification)

          ;; Add classification and timestamp to metadata
          metadata (assoc metadata
                         :classification classification
                         :modified (str (time/instant))
                         :s3_key object-key)]

      ;; Store classification in DynamoDB
      (ddb/put-item ddb-table
                    (assoc metadata
                           :pk object-key
                           :sk "METADATA"
                           :document_path object-key))

      ;; Invoke update-classification-index Lambda asynchronously
      (when update-index-lambda
        (lambda/invoke-async update-index-lambda
                            {:classification classification
                             :document-path object-key})
        (println "Triggered classification index update"))

      {:classification classification
       :title (:title metadata)})))

(defn handler
  "Lambda handler for EventBridge S3 events"
  [event context]
  (try
    (println "Received event:" (json/write-str event))

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
           :body (json/write-str {:message "Skipped file"
                                  :object-key object-key})})

        ;; Classify the document
        (let [result (classify-document bucket-name object-key)]
          {:statusCode 200
           :body (json/write-str {:document object-key
                                  :classification (:classification result)})})))

    (catch Exception e
      (println "Error processing document:" (.getMessage e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/write-str {:error (.getMessage e)})})))

;; For local testing
(defn -main [& args]
  (let [test-event {:detail {:bucket {:name s3-bucket}
                             :object {:key "test.md"}}}]
    (println "Running test with event:" test-event)
    (println "Result:" (handler test-event nil))))
