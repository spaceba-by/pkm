(ns handler
  "Lambda function to extract metadata from markdown documents"
  (:require [aws.s3 :as s3]
            [aws.dynamodb :as ddb]
            [markdown.utils :as md]
            [clojure.data.json :as json]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn should-skip?
  "Check if file should be skipped based on path"
  [object-key]
  (or
   ;; Skip non-markdown files
   (not (.endsWith object-key ".md"))
   ;; Skip _agent directory
   (.startsWith object-key "_agent/")
   ;; Skip .obsidian directory
   (.startsWith object-key ".obsidian/")))

(defn extract-metadata
  "Extract and store metadata for a markdown document"
  [bucket-name object-key]
  (println "Extracting metadata from:" object-key)

  ;; Get document content
  (let [content (s3/get-object bucket-name object-key)]

    (when (empty? content)
      (println "Warning: Empty content for" object-key)
      (throw (ex-info "Empty document" {:object-key object-key})))

    ;; Parse metadata (no AI needed - pure parsing)
    (let [metadata (md/parse-markdown-metadata content)
          now (str (java.time.Instant/now))
          metadata (-> metadata
                       (assoc :s3_key object-key)
                       (assoc :modified now)
                       (update :created #(or % now)))]

      (println "Extracted metadata from" object-key ":" (:title metadata))

      ;; Store metadata in DynamoDB
      ;; Use s3_key as partition key for document metadata
      (ddb/put-item ddb-table
                    (assoc metadata
                           :pk object-key
                           :sk "METADATA"))

      ;; Store tag index entries
      (when-let [tags (:tags metadata)]
        (doseq [tag tags]
          (try
            (ddb/put-item ddb-table
                          {:pk (str "tag#" tag)
                           :sk (str "doc#" object-key)
                           :tag_name tag
                           :document_path object-key
                           :modified now})
            (catch Exception e
              (println "Error storing tag index for" tag ":" (.getMessage e))))))

      metadata)))

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

        ;; Process the document
        (let [metadata (extract-metadata bucket-name object-key)]
          {:statusCode 200
           :body (json/write-str {:document object-key
                                  :metadata {:title (:title metadata)
                                             :tags (:tags metadata [])
                                             :links (count (:links_to metadata []))}})})))

    (catch Exception e
      (println "Error extracting metadata:" (.getMessage e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/write-str {:error (.getMessage e)})})))

;; For local testing
(defn -main [& args]
  (let [test-event {:detail {:bucket {:name s3-bucket}
                             :object {:key "test.md"}}}]
    (println "Running test with event:" test-event)
    (println "Result:" (handler test-event nil))))
