(ns handler
  "API Lambda: Get dispatch job details"
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def s3-bucket (System/getenv "S3_BUCKET_NAME"))

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
        (let [path-params (r/parse-path-params event)
              job-id (or (get path-params "jobId") (get path-params :jobId))
              _ (when-not job-id
                  (throw (ex-info "Missing jobId" {:type :validation})))
              job (ddb/get-item ddb-table {:PK "dispatch#job"
                                           :SK (str "job#" job-id)})]
          (if job
            (let [formatted (format-job job)
                  ;; Include result content if completed
                  result (when (= "completed" (:status job))
                           (try
                             (s3/get-object s3-bucket
                                            (str "_agent/dispatch/" job-id "/result.md"))
                             (catch Exception _ nil)))]
              (r/ok (cond-> {:job formatted}
                      result (assoc :result result))))
            (r/not-found (str "Job not found: " job-id))))))

    (catch clojure.lang.ExceptionInfo e
      (if (= :validation (:type (ex-data e)))
        (r/bad-request (ex-message e))
        (do
          (println "Error getting job:" (ex-message e))
          (r/internal-error "Failed to get job"))))

    (catch Exception e
      (println "Error getting job:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to get job"))))
