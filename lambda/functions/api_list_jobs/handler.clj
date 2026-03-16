(ns handler
  "API Lambda: List dispatch jobs with filtering and pagination"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json])
  (:import [java.util Base64]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def default-limit 50)
(def max-limit 100)

(defn encode-cursor [last-key]
  (when last-key
    (.encodeToString (Base64/getUrlEncoder)
                     (.getBytes (json/generate-string last-key) "UTF-8"))))

(defn decode-cursor [cursor]
  (when (and cursor (not (empty? cursor)))
    (try
      (let [decoded (String. (.decode (Base64/getUrlDecoder) cursor) "UTF-8")]
        (json/parse-string decoded true))
      (catch Exception _ nil))))

(defn- format-job
  "Format a job record for API response"
  [job]
  (cond-> {:jobId (:job_id job)
           :status (:status job)
           :agentType (:agent_type job)
           :taskDescription (:task_description job)
           :created (r/truncate-timestamp (:created job))
           :updated (r/truncate-timestamp (:updated job))}
    (:context_paths job) (assoc :contextPaths (:context_paths job))
    (:started_at job) (assoc :startedAt (r/truncate-timestamp (:started_at job)))
    (:completed_at job) (assoc :completedAt (r/truncate-timestamp (:completed_at job)))
    (:error job) (assoc :error (:error job))
    (:artifacts job) (assoc :artifacts (:artifacts job))
    (:result_path job) (assoc :resultPath (:result_path job))
    (:ecs_task_arn job) (assoc :ecsTaskArn (:ecs_task_arn job))
    (:claimed_by job) (assoc :claimedBy (:claimed_by job))
    (:created_by job) (assoc :createdBy (:created_by job))))

(defn handler [request]
  (try
    (let [event (json/parse-string (:body request) true)
          admin-check (r/require-admin event)]
      (if admin-check
        admin-check
        (let [params (r/parse-query-params event)
              status-filter (or (get params "status") (get params :status))
              limit (min (r/parse-int-param params "limit" default-limit) max-limit)
              cursor (or (get params "cursor") (get params :cursor))
              start-key (decode-cursor cursor)
              ;; Query all jobs from dispatch#job partition
              [items last-key] (ddb/query-to-limit ddb-table
                                                    :key-condition-expr "PK = :pk AND begins_with(SK, :sk_prefix)"
                                                    :expr-attr-values {":pk" "dispatch#job"
                                                                       ":sk_prefix" "job#"}
                                                    :limit (if status-filter (* 3 limit) limit)
                                                    :scan-index-forward false
                                                    :exclusive-start-key start-key)
              ;; Filter by status if requested
              filtered (if status-filter
                         (filterv #(= status-filter (:status %)) items)
                         items)
              result-items (vec (take limit filtered))
              formatted (mapv format-job result-items)
              ;; Build cursor from last returned item's keys (not DynamoDB's LastEvaluatedKey)
              ;; to avoid skipping items when filtering
              next-cursor (when (and last-key (= (count result-items) limit))
                            (let [last-item (peek result-items)]
                              (encode-cursor {:PK (:PK last-item) :SK (:SK last-item)})))]

          (r/ok {:jobs formatted
                 :count (count formatted)
                 :nextCursor next-cursor}))))

    (catch Exception e
      (println "Error listing jobs:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to list jobs"))))
