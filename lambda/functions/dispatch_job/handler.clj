(ns handler
  "Processing Lambda: Create dispatch jobs and launch ECS tasks or queue for local agents"
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [aws.ecs :as ecs]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def s3-bucket (System/getenv "S3_BUCKET_NAME"))

(defn- generate-job-id []
  (str (java.util.UUID/randomUUID)))

(defn- now-iso []
  (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS)))

(defn- get-agent-type-config
  "Look up agent type configuration from DynamoDB"
  [agent-type-name]
  (ddb/get-item ddb-table {:PK "dispatch#agent-type"
                           :SK (str "type#" agent-type-name)}))

(defn- write-job-input
  "Write job input context to S3"
  [job-id task-description context-paths]
  (let [input {:task_description task-description
               :context_paths (or context-paths [])
               :created_at (now-iso)}
        key (str "_agent/dispatch/" job-id "/input.json")]
    (s3/put-object s3-bucket key (json/generate-string input))
    key))

(defn- create-job-record
  "Create the job record in DynamoDB"
  [job-id agent-type-name task-description context-paths created-by]
  (let [now (now-iso)
        item {:PK "dispatch#job"
              :SK (str "job#" job-id)
              :job_id job-id
              :status "pending"
              :agent_type agent-type-name
              :task_description task-description
              :context_paths (or context-paths [])
              :created now
              :updated now
              :created_by (or created-by "system")}]
    (ddb/put-item ddb-table item)
    item))

(defn- launch-ecs-task
  "Launch an ECS Fargate task for the job using agent type config"
  [job-id agent-type-config]
  (let [cluster (or (:ecs_cluster agent-type-config) (System/getenv "ECS_CLUSTER_NAME"))
        task-def (or (:ecs_task_definition agent-type-config) (System/getenv "ECS_TASK_DEFINITION"))
        subnets (or (:ecs_subnets agent-type-config) [(System/getenv "ECS_SUBNET_ID")])
        security-groups (or (:ecs_security_groups agent-type-config) [(System/getenv "ECS_SECURITY_GROUP_ID")])
        container-name (or (:container_name agent-type-config) "dispatch-sandbox")
        env-overrides (merge {"JOB_ID" job-id
                              "S3_BUCKET" s3-bucket
                              "INPUT_PATH" (str "_agent/dispatch/" job-id "/input.json")
                              "OUTPUT_PATH" (str "_agent/dispatch/" job-id "/output/")}
                             (or (:env_vars agent-type-config) {}))
        task (ecs/run-task {:cluster cluster
                            :task-definition task-def
                            :subnets subnets
                            :security-groups security-groups
                            :container-name container-name
                            :env-overrides env-overrides})]
    (:taskArn task)))

(defn handler
  "Lambda handler for job dispatch"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          ;; Support both direct invocation and Lambda async invocation
          payload (or (:detail event) event)
          task-description (:task_description payload)
          agent-type-name (:agent_type payload)
          context-paths (:context_paths payload)
          created-by (:created_by payload)]

      (when-not task-description
        (throw (ex-info "Missing task_description" {:type :validation})))
      (when-not agent-type-name
        (throw (ex-info "Missing agent_type" {:type :validation})))

      ;; Look up agent type config
      (let [agent-type-config (get-agent-type-config agent-type-name)]
        (when-not agent-type-config
          (throw (ex-info (str "Unknown agent type: " agent-type-name)
                          {:type :validation})))

        (let [job-id (or (:job_id payload) (:job_id_hint payload) (generate-job-id))
              target (or (:target agent-type-config) "ecs")]

          ;; Write input context to S3
          (write-job-input job-id task-description context-paths)

          ;; Create job record
          (create-job-record job-id agent-type-name task-description context-paths created-by)

          (println "Created dispatch job" job-id "agent-type:" agent-type-name "target:" target)

          ;; Dispatch based on target
          (if (= target "ecs")
            (let [task-arn (launch-ecs-task job-id agent-type-config)]
              ;; Update job status to running with task ARN
              (ddb/update-item-attrs ddb-table
                                     {:PK "dispatch#job" :SK (str "job#" job-id)}
                                     {:status "running"
                                      :ecs_task_arn task-arn
                                      :started_at (now-iso)
                                      :updated (now-iso)})
              (println "Launched ECS task" task-arn "for job" job-id)
              {:statusCode 200
               :body (json/generate-string {:job_id job-id
                                            :status "running"
                                            :ecs_task_arn task-arn})})

            ;; Local target: leave as pending for local agent to claim
            (do
              (println "Job" job-id "queued for local agent claiming")
              {:statusCode 200
               :body (json/generate-string {:job_id job-id
                                            :status "pending"
                                            :target "local"})})))))

    (catch clojure.lang.ExceptionInfo e
      (if (= :validation (:type (ex-data e)))
        {:statusCode 400
         :body (json/generate-string {:error (ex-message e)})}
        (do
          (println "Error dispatching job:" (ex-message e))
          (.printStackTrace e)
          {:statusCode 500
           :body (json/generate-string {:error "Failed to dispatch job"})})))

    (catch Exception e
      (println "Error dispatching job:" (ex-message e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:error "Failed to dispatch job"})})))
