(ns handler
  "Processing Lambda: Collect results from completed dispatch jobs.
   Triggered by ECS task state changes (STOPPED) via EventBridge,
   or invoked directly by api_complete_job for local agent results."
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def s3-bucket (System/getenv "S3_BUCKET_NAME"))

(defn- now-iso []
  (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS)))

(defn- extract-job-id-from-ecs-event
  "Extract job ID from ECS task state change event.
   The job ID is passed as an environment variable override."
  [event]
  (let [detail (:detail event)
        overrides (get-in detail [:overrides :containerOverrides])
        envs (mapcat :environment overrides)
        job-env (first (filter #(= "JOB_ID" (:name %)) envs))]
    (:value job-env)))

(defn- collect-artifacts
  "List all artifacts produced by the job in S3"
  [job-id]
  (let [prefix (str "_agent/dispatch/" job-id "/output/")
        keys (s3/list-objects s3-bucket prefix)]
    (mapv #(str/replace-first % prefix "") keys)))

(defn- read-output-summary
  "Read the main output/result from the job, if it exists"
  [job-id]
  (let [key (str "_agent/dispatch/" job-id "/output/result.md")]
    (try
      (s3/get-object s3-bucket key)
      (catch Exception _
        nil))))

(defn- write-result-summary
  "Write a summary of the job result to the vault"
  [job-id task-description status artifacts result-content]
  (let [summary (str "# Dispatch Job Result: " job-id "\n\n"
                      "**Task:** " task-description "\n"
                      "**Status:** " status "\n"
                      "**Completed:** " (now-iso) "\n\n"
                      (when (seq artifacts)
                        (str "## Artifacts\n\n"
                             (str/join "\n" (map #(str "- " %) artifacts))
                             "\n\n"))
                      (when result-content
                        (str "## Result\n\n" result-content "\n")))
        key (str "_agent/dispatch/" job-id "/result.md")]
    (s3/put-object s3-bucket key summary)
    key))

(defn- determine-exit-status
  "Determine job status from ECS task exit code or explicit status"
  [event explicit-status]
  (if explicit-status
    explicit-status
    ;; From ECS event: check container exit codes
    (let [containers (get-in event [:detail :containers])]
      (if (every? #(= 0 (:exitCode %)) containers)
        "completed"
        "failed"))))

(defn- determine-error
  "Extract error message from ECS event or explicit error"
  [event explicit-error]
  (if explicit-error
    explicit-error
    ;; From ECS event: check stopped reason
    (let [reason (get-in event [:detail :stoppedReason])]
      (when (and reason (not= reason "Essential container in task exited"))
        reason))))

(defn collect-job-results
  "Core result collection logic, used by both ECS events and local agent completion"
  [job-id status error-msg]
  (let [job (ddb/get-item ddb-table {:PK "dispatch#job" :SK (str "job#" job-id)})]
    (when-not job
      (throw (ex-info (str "Job not found: " job-id) {:type :not-found})))

    (let [artifacts (collect-artifacts job-id)
          result-content (read-output-summary job-id)
          result-path (write-result-summary job-id (:task_description job)
                                             status artifacts result-content)
          now (now-iso)
          update-attrs (cond-> {:status status
                                :updated now
                                :completed_at now
                                :result_path result-path}
                         (seq artifacts) (assoc :artifacts artifacts)
                         error-msg (assoc :error error-msg))]

      (ddb/update-item-attrs ddb-table
                              {:PK "dispatch#job" :SK (str "job#" job-id)}
                              update-attrs)

      (println "Collected results for job" job-id "status:" status
               "artifacts:" (count artifacts))

      {:job_id job-id
       :status status
       :artifacts artifacts
       :result_path result-path})))

(defn handler
  "Lambda handler for result collection"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)]

      (cond
        ;; ECS task state change event
        (= "ECS Task State Change" (get-in event [:detail-type]))
        (let [job-id (extract-job-id-from-ecs-event event)
              status (determine-exit-status event nil)
              error-msg (determine-error event nil)]
          (if job-id
            (do
              (let [result (collect-job-results job-id status error-msg)]
                {:statusCode 200
                 :body (json/generate-string result)}))
            (do
              (println "No JOB_ID found in ECS task event, skipping")
              {:statusCode 200
               :body (json/generate-string {:message "No JOB_ID in task"})})))

        ;; Direct invocation (from api_complete_job)
        (:job_id event)
        (let [result (collect-job-results (:job_id event)
                                          (or (:status event) "completed")
                                          (:error event))]
          {:statusCode 200
           :body (json/generate-string result)})

        :else
        {:statusCode 400
         :body (json/generate-string {:error "Unrecognized event format"})}))

    (catch clojure.lang.ExceptionInfo e
      (println "Error collecting results:" (ex-message e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:error (ex-message e)})})

    (catch Exception e
      (println "Error collecting results:" (ex-message e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:error "Failed to collect results"})})))
