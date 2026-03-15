(ns handler
  "API Lambda: List extracted tasks with filtering and pagination"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json])
  (:import [java.util Base64]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def default-limit 50)
(def max-limit 100)

(defn encode-cursor
  "Encode a DynamoDB LastEvaluatedKey as a base64 JSON string"
  [last-key]
  (when last-key
    (.encodeToString (Base64/getUrlEncoder)
                     (.getBytes (json/generate-string last-key) "UTF-8"))))

(defn decode-cursor
  "Decode a base64 JSON cursor back to a DynamoDB ExclusiveStartKey map"
  [cursor]
  (when (and cursor (not (empty? cursor)))
    (try
      (let [decoded (String. (.decode (Base64/getUrlDecoder) cursor) "UTF-8")]
        (json/parse-string decoded true))
      (catch Exception _
        nil))))

(defn- query-tasks-by-status
  "Query tasks using the task-index GSI filtered by status."
  [status limit cursor]
  (let [start-key (decode-cursor cursor)
        [items last-key] (ddb/query-to-limit ddb-table
                                              :index-name "task-index"
                                              :key-condition-expr "task_status = :status"
                                              :expr-attr-values {":status" status}
                                              :limit limit
                                              :scan-index-forward false
                                              :exclusive-start-key start-key)]
    [items (encode-cursor last-key)]))

(defn- query-tasks-by-document
  "Query tasks for a specific document from its METADATA item."
  [document-path status]
  (let [item (ddb/get-item ddb-table {:PK document-path :SK "METADATA"})
        tasks (or (:tasks item) [])]
    (if (= status "all")
      tasks
      (filterv #(= status (:status %)) tasks))))

(defn- format-task
  "Format a task index entry for API response."
  [task]
  (cond-> {:taskId (or (:task_id task) "")
           :description (or (:description task) "")
           :status (or (:status task) (:task_status task) "open")
           :source (or (:source task) "pattern")
           :marker (or (:marker task) "checkbox")
           :documentPath (or (:document_path task) "")}
    (:line_number task) (assoc :lineNumber (:line_number task))
    (:due_date task) (assoc :dueDate (:due_date task))
    (:priority task) (assoc :priority (:priority task))
    (:context task) (assoc :context (:context task))
    (:modified task) (assoc :modified (r/truncate-timestamp (:modified task)))))

(defn handler
  "Lambda handler for task listing API"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          params (r/parse-query-params event)
          user-sub (r/get-user-sub event)
          status (or (get params "status") (get params :status) "open")
          document (or (get params "document") (get params :document))
          limit (min (r/parse-int-param params "limit" default-limit) max-limit)
          cursor (or (get params "cursor") (get params :cursor))]

      (println "User" user-sub "listing tasks, status:" status "document:" document)

      ;; Validate status parameter
      (when-not (#{"open" "completed" "all"} status)
        (throw (ex-info "Invalid status" {:type :validation
                                          :status status})))

      (if document
        ;; Filter by specific document
        (let [tasks (query-tasks-by-document document status)
              formatted (mapv format-task tasks)]
          (r/ok {:tasks formatted
                 :count (count formatted)
                 :nextCursor nil}))

        ;; Query by status using GSI
        (if (= status "all")
          ;; For "all", query both open and completed, merge
          (let [half-limit (max 1 (quot limit 2))
                [open-tasks open-cursor] (query-tasks-by-status "open" half-limit cursor)
                [completed-tasks _] (query-tasks-by-status "completed" half-limit nil)
                all-tasks (into (vec open-tasks) completed-tasks)
                formatted (mapv format-task all-tasks)]
            (r/ok {:tasks formatted
                   :count (count formatted)
                   :nextCursor open-cursor}))

          ;; Single status query
          (let [[tasks next-cursor] (query-tasks-by-status status limit cursor)
                formatted (mapv format-task tasks)]
            (r/ok {:tasks formatted
                   :count (count formatted)
                   :nextCursor next-cursor})))))

    (catch clojure.lang.ExceptionInfo e
      (if (= :validation (:type (ex-data e)))
        (r/bad-request (ex-message e))
        (do
          (println "Error listing tasks:" (ex-message e))
          (.printStackTrace e)
          (r/internal-error "Failed to list tasks"))))

    (catch Exception e
      (println "Error listing tasks:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to list tasks"))))
