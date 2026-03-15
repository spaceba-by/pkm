(ns handler
  "Lambda function to extract tasks from markdown documents.
   Detects checkboxes, TODO/ACTION/FIXME markers, and uses AI for
   implicit task detection in meeting/project documents."
  (:require [aws.s3 :as s3]
            [aws.dynamodb :as ddb]
            [tasks.extractor :as extractor]
            [markdown.utils :as md]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def bedrock-model (System/getenv "BEDROCK_MODEL_ID"))

(defn should-skip?
  "Check if file should be skipped"
  [object-key]
  (or
   (not (.endsWith object-key ".md"))
   (.startsWith object-key "_agent/")
   (.startsWith object-key ".obsidian/")))

(defn- get-document-classification
  "Look up the document's classification from DynamoDB.
   Returns nil if not yet classified."
  [object-key]
  (when-let [item (ddb/get-item ddb-table {:PK object-key :SK "METADATA"})]
    (:classification item)))

(defn- delete-existing-task-index
  "Remove all existing task index entries for a document.
   Queries both task#open and task#completed partitions."
  [object-key]
  (let [doc-prefix (str "doc#" object-key "#")]
    (doseq [status-key ["task#open" "task#completed"]]
      (let [entries (ddb/query ddb-table
                               :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                               :expr-attr-values {":pk" status-key
                                                   ":prefix" doc-prefix})]
        (doseq [entry entries]
          (ddb/delete-item ddb-table {:PK (:PK entry) :SK (:SK entry)}))))))

(defn- store-task-index-entries
  "Create task index entries for cross-document querying."
  [object-key tasks]
  (let [now (md/now-iso)]
    (doseq [task tasks]
      (let [task-id (:task_id task)
            status-key (str "task#" (:status task))
            sk (str "doc#" object-key "#" task-id)]
        (ddb/put-item ddb-table
                      (cond-> {:PK status-key
                               :SK sk
                               :task_status (:status task)
                               :description (:description task)
                               :document_path object-key
                               :task_id task-id
                               :marker (:marker task)
                               :source (:source task)
                               :modified now}
                        (:due_date task) (assoc :due_date (:due_date task))
                        (:priority task) (assoc :priority (:priority task))
                        (:line_number task) (assoc :line_number (:line_number task))))))))

(defn extract-and-store-tasks
  "Extract tasks from document and store in DynamoDB."
  [bucket-name object-key]
  (println "Extracting tasks from:" object-key)

  (let [content (s3/get-object bucket-name object-key)]
    (when (str/blank? content)
      (println "Warning: Empty content for" object-key)
      (throw (ex-info "Empty document" {:object-key object-key})))

    ;; Pattern-based extraction (always runs)
    (let [pattern-tasks (extractor/extract-pattern-tasks content)

          ;; AI extraction (only for meeting/project documents)
          classification (get-document-classification object-key)
          ai-tasks (if (and bedrock-model
                            (#{"meeting" "project"} classification))
                     (do
                       (println "Running AI extraction for" classification "document:" object-key)
                       (extractor/extract-ai-tasks bedrock-model content))
                     [])

          ;; Merge and deduplicate
          all-tasks (extractor/merge-tasks pattern-tasks ai-tasks)

          ;; Generate task IDs
          tasks-with-ids (mapv (fn [task]
                                 (assoc task :task_id
                                        (extractor/generate-task-id
                                         object-key
                                         (:line_number task)
                                         (:description task))))
                               all-tasks)]

      (println "Found" (count tasks-with-ids) "tasks in" object-key
               "(" (count pattern-tasks) "pattern," (count ai-tasks) "AI)")

      ;; Delete old task index entries
      (delete-existing-task-index object-key)

      ;; Store tasks on document METADATA
      (ddb/update-item-attrs ddb-table
                             {:PK object-key :SK "METADATA"}
                             {:tasks tasks-with-ids
                              :tasks_extracted_at (md/now-iso)
                              :task_count (count tasks-with-ids)
                              :open_task_count (count (filter #(= "open" (:status %)) tasks-with-ids))})

      ;; Create new task index entries
      (when (seq tasks-with-ids)
        (store-task-index-entries object-key tasks-with-ids))

      {:tasks tasks-with-ids
       :task-count (count tasks-with-ids)})))

(defn handler
  "Lambda handler for bblf runtime"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)]
      (println "Received event:" (json/generate-string event))

      (let [detail (get event :detail {})
            bucket-name (get-in detail [:bucket :name])
            object-key (get-in detail [:object :key])]

        (when (or (nil? bucket-name) (nil? object-key))
          (println "Error: Missing bucket name or object key in event")
          (throw (ex-info "Invalid event format" {:event event})))

        (if (should-skip? object-key)
          (do
            (println "Skipping file:" object-key)
            {:statusCode 200
             :body (json/generate-string {:message "Skipped file"
                                          :object-key object-key})})

          (let [result (extract-and-store-tasks bucket-name object-key)]
            {:statusCode 200
             :body (json/generate-string {:document object-key
                                          :task-count (:task-count result)})}))))

    (catch Exception e
      (println "Error extracting tasks:" (ex-message e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:error (ex-message e)})})))
