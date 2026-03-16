(ns handler
  "API Lambda: Create a new dispatch job"
  (:require [aws.dynamodb :as ddb]
            [aws.lambda :as lambda]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def dispatch-function-name (System/getenv "DISPATCH_FUNCTION_NAME"))

(defn handler [request]
  (try
    (let [event (json/parse-string (:body request) true)
          admin-check (r/require-admin event)]
      (if admin-check
        admin-check
        (let [user-sub (r/get-user-sub event)
              body (when-let [b (or (:body event) (get event "body"))]
                     (if (string? b) (json/parse-string b true) b))
              task-description (or (:taskDescription body) (:task_description body))
              agent-type (or (:agentType body) (:agent_type body))
              context-paths (or (:contextPaths body) (:context_paths body))]

          (when-not task-description
            (throw (ex-info "Missing taskDescription" {:type :validation})))
          (when-not agent-type
            (throw (ex-info "Missing agentType" {:type :validation})))

          ;; Verify agent type exists
          (let [agent-type-config (ddb/get-item ddb-table
                                                 {:PK "dispatch#agent-type"
                                                  :SK (str "type#" agent-type)})]
            (when-not agent-type-config
              (throw (ex-info (str "Unknown agent type: " agent-type)
                              {:type :validation})))

            ;; Generate job ID for tracking
            (let [job-id (str (java.util.UUID/randomUUID))]
              ;; Invoke dispatch_job Lambda asynchronously
              (lambda/invoke-async
               (or dispatch-function-name "pkm-agent-dispatch-job")
               {:task_description task-description
                :agent_type agent-type
                :context_paths context-paths
                :created_by user-sub
                :job_id_hint job-id})

              (r/accepted {:jobId job-id
                           :agentType agent-type
                           :status "accepted"}))))))

    (catch clojure.lang.ExceptionInfo e
      (if (= :validation (:type (ex-data e)))
        (r/bad-request (ex-message e))
        (do
          (println "Error creating job:" (ex-message e))
          (r/internal-error "Failed to create job"))))

    (catch Exception e
      (println "Error creating job:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to create job"))))
