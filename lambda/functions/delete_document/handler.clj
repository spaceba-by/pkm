(ns handler
  "Lambda function for document deletion cleanup.
   Triggered by S3 Object Deleted EventBridge events.
   Cascade-deletes all related DynamoDB records (METADATA, tag index, entity index)."
  (:require [shared.deletion :as deletion]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn should-skip?
  "Check if file should be skipped based on path"
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

(defn handler
  "Lambda handler for bblf runtime - receives S3 Object Deleted events via EventBridge"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)]
      (println "Received delete event:" (json/generate-string event))

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

          ;; Cascade-delete all DynamoDB records
          (let [result (deletion/cascade-delete-document ddb-table object-key)]
            (println "Delete cleanup complete for" object-key)
            {:statusCode 200
             :body (json/generate-string result)}))))

    (catch Exception e
      (println "Error processing delete event:" (ex-message e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:error (ex-message e)})})))
