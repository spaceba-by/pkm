(ns handler
  "API Lambda: Complete a dispatch job (called by local agents)"
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def s3-bucket (System/getenv "S3_BUCKET_NAME"))

(defn- now-iso []
  (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS)))

(defn- collect-artifacts
  "List all artifacts produced by the job in S3"
  [job-id]
  (let [prefix (str "_agent/dispatch/" job-id "/output/")
        keys (s3/list-objects s3-bucket prefix)]
    (mapv #(str/replace-first % prefix "") keys)))

(defn- write-result-summary
  "Write a summary of the job result to the vault"
  [job-id task-description status artifacts error-msg]
  (let [summary (str "# Dispatch Job Result: " job-id "\n\n"
                      "**Task:** " task-description "\n"
                      "**Status:** " status "\n"
                      "**Completed:** " (now-iso) "\n\n"
                      (when error-msg
                        (str "**Error:** " error-msg "\n\n"))
                      (when (seq artifacts)
                        (str "## Artifacts\n\n"
                             (str/join "\n" (map #(str "- " %) artifacts))
                             "\n")))
        key (str "_agent/dispatch/" job-id "/result.md")]
    (s3/put-object s3-bucket key summary)
    key))

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
              body (when-let [b (or (:body event) (get event "body"))]
                     (if (string? b) (json/parse-string b true) b))
              status (or (:status body) "completed")
              error-msg (:error body)]

          (when-not (#{"completed" "failed"} status)
            (throw (ex-info "Status must be 'completed' or 'failed'" {:type :validation})))

          ;; Verify job exists and is running
          (let [job (ddb/get-item ddb-table {:PK "dispatch#job"
                                              :SK (str "job#" job-id)})]
            (when-not job
              (throw (ex-info (str "Job not found: " job-id) {:type :not-found})))
            (when-not (= "running" (:status job))
              (throw (ex-info (str "Job is not running (status: " (:status job) ")")
                              {:type :validation})))

            ;; Collect artifacts and write summary
            (let [artifacts (collect-artifacts job-id)
                  result-path (write-result-summary job-id (:task_description job)
                                                     status artifacts error-msg)
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

              (println "Completed job" job-id "status:" status "artifacts:" (count artifacts))

              (r/ok {:jobId job-id
                     :status status
                     :artifacts artifacts
                     :resultPath result-path}))))))

    (catch clojure.lang.ExceptionInfo e
      (let [data (ex-data e)]
        (case (:type data)
          :validation (r/bad-request (ex-message e))
          :not-found (r/not-found (ex-message e))
          (do
            (println "Error completing job:" (ex-message e))
            (r/internal-error "Failed to complete job")))))

    (catch Exception e
      (println "Error completing job:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to complete job"))))
