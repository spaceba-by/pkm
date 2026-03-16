(ns handler
  "API Lambda: Claim a pending local dispatch job.
   Local agents poll this endpoint to pick up work."
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def s3-bucket (System/getenv "S3_BUCKET_NAME"))

(defn- now-iso []
  (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS)))

(defn- get-local-agent-types
  "Get the set of agent type names that have target=local"
  [requested-types]
  (filterv (fn [type-name]
             (let [config (ddb/get-item ddb-table {:PK "dispatch#agent-type"
                                                    :SK (str "type#" type-name)})]
               (and config (= "local" (:target config)))))
           requested-types))

(defn- find-claimable-job
  "Find the oldest pending job matching any of the given agent types"
  [agent-types]
  (let [all-jobs (ddb/query ddb-table
                            :key-condition-expr "PK = :pk AND begins_with(SK, :sk_prefix)"
                            :expr-attr-values {":pk" "dispatch#job"
                                               ":sk_prefix" "job#"}
                            :limit 100)
        pending-jobs (filter #(= "pending" (:status %)) all-jobs)
        matching-jobs (filter #(some #{(:agent_type %)} agent-types) pending-jobs)]
    ;; Return oldest first (sort by created ascending)
    (first (sort-by :created matching-jobs))))

(defn- try-claim-job
  "Attempt to atomically claim a job using conditional update.
   Returns the updated job if successful, nil if already claimed."
  [job claimed-by]
  (try
    (let [now (now-iso)
          result (ddb/update-item ddb-table
                                  {:PK "dispatch#job" :SK (:SK job)}
                                  "SET #s = :running, claimed_by = :cb, started_at = :sa, updated = :u"
                                  {":running" "running"
                                   ":cb" claimed-by
                                   ":sa" now
                                   ":u" now
                                   ":pending" "pending"}
                                  :expr-attr-names {"#s" "status"})]
      result)
    (catch Exception _
      ;; Conditional check failed — job was already claimed
      nil)))

(defn- read-job-input
  "Read job input context from S3"
  [job-id]
  (try
    (let [key (str "_agent/dispatch/" job-id "/input.json")
          content (s3/get-object s3-bucket key)]
      (json/parse-string content true))
    (catch Exception _
      nil)))

(defn- format-job [job]
  (cond-> {:jobId (:job_id job)
           :status (:status job)
           :agentType (:agent_type job)
           :taskDescription (:task_description job)
           :created (r/truncate-timestamp (:created job))
           :updated (r/truncate-timestamp (:updated job))}
    (:context_paths job) (assoc :contextPaths (:context_paths job))
    (:started_at job) (assoc :startedAt (r/truncate-timestamp (:started_at job)))
    (:claimed_by job) (assoc :claimedBy (:claimed_by job))))

(defn handler [request]
  (try
    (let [event (json/parse-string (:body request) true)
          admin-check (r/require-admin event)]
      (if admin-check
        admin-check
        (let [user-sub (r/get-user-sub event)
              body (when-let [b (or (:body event) (get event "body"))]
                     (if (string? b) (json/parse-string b true) b))
              requested-types (or (:agentTypes body) (:agent_types body))
              claimed-by (or (:claimedBy body) (:claimed_by body) user-sub)]

          (when-not (seq requested-types)
            (throw (ex-info "Missing agentTypes" {:type :validation})))

          ;; Verify requested types are local targets
          (let [local-types (get-local-agent-types requested-types)]
            (if (empty? local-types)
              (r/no-content)
              (if-let [job (find-claimable-job local-types)]
                ;; Try to claim atomically
                (if-let [claimed (try-claim-job job claimed-by)]
                  (let [input (read-job-input (:job_id claimed))]
                    (r/ok {:job (format-job claimed)
                           :input input}))
                  ;; Race condition — job was claimed by another agent
                  (r/no-content))
                ;; No pending jobs
                (r/no-content)))))))

    (catch clojure.lang.ExceptionInfo e
      (if (= :validation (:type (ex-data e)))
        (r/bad-request (ex-message e))
        (do
          (println "Error claiming job:" (ex-message e))
          (r/internal-error "Failed to claim job"))))

    (catch Exception e
      (println "Error claiming job:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to claim job"))))
