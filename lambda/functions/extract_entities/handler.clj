(ns handler
  "Lambda function to extract entities from markdown documents using Bedrock"
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
   ;; Skip .obsidian directory
   (.startsWith object-key ".obsidian/")))

(defn extract-and-store-entities
  "Extract entities from document and store in DynamoDB and S3"
  [bucket-name object-key]
  (println "Extracting entities from:" object-key)

  ;; Get document content
  (let [content (s3/get-object bucket-name object-key)]

    (when (empty? content)
      (println "Warning: Empty content for" object-key)
      (throw (ex-info "Empty document" {:object-key object-key})))

    ;; Extract entities using Bedrock
    (let [entities (bedrock/extract-entities bedrock-model content)]

      (println "Extracted entities from" object-key ":" entities)

      ;; Store entities in DynamoDB
      (ddb/store-entities ddb-table object-key entities)

      ;; Create/update entity pages in S3
      (let [total-entities (atom 0)]
        (doseq [[entity-type entity-list] entities
                entity-name entity-list]

          ;; Get existing mentions for this entity
          (let [existing-mentions (ddb/get-entity-mentions ddb-table
                                                          (name entity-type)
                                                          entity-name)

                ;; Create mentions list
                mentions (mapv (fn [path]
                                {:path path
                                 :context (str "Mentioned in " path)})
                              existing-mentions)

                ;; Create entity page content
                entity-page-content (md/create-entity-page entity-name
                                                           (name entity-type)
                                                           mentions)

                ;; Upload entity page
                entity-filename (str (md/sanitize-filename entity-name) ".md")
                _ (s3/put-agent-output bucket-name
                                      (str "entities/" (name entity-type))
                                      entity-filename
                                      entity-page-content)]

            (swap! total-entities inc)))

        (println "Created/updated" @total-entities "entity pages")

        {:entities entities
         :entity-pages-created @total-entities}))))

(defn handler
  "Lambda handler for bblf runtime - receives raw HTTP request from Lambda Runtime API"
  [request]
  (try
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

          ;; Extract entities from the document
          (let [result (extract-and-store-entities bucket-name object-key)]
            {:statusCode 200
             :body (json/generate-string {:document object-key
                                          :entities (:entities result)
                                          :entity-pages-created (:entity-pages-created result)})}))))

    (catch Exception e
      (println "Error extracting entities:" (.getMessage e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:error (.getMessage e)})})))

;; For local testing
(defn -main []
  (let [test-event {:detail {:bucket {:name s3-bucket}
                             :object {:key "test.md"}}}]
    (println "Running test with event:" test-event)
    (println "Result:" (handler test-event))))
