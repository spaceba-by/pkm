(ns aws.ecs
  "ECS operations using awyeah client"
  (:require [com.grzm.awyeah.client.api :as aws]))

(defonce ^:private ecs-client
  (delay (aws/client {:api :ecs})))

(defn- check-error
  "Check AWS response for errors and throw if found"
  [response operation]
  (when-let [error-category (:cognitect.anomalies/category response)]
    (throw (ex-info (str "ECS " operation " failed: "
                         (or (:message response) error-category))
                    {:operation operation
                     :error-category error-category
                     :error-code (:cognitect.aws.error/code response)
                     :response response})))
  response)

(defn run-task
  "Run an ECS Fargate task.
   Options:
     :cluster - ECS cluster name or ARN
     :task-definition - Task definition family:revision or ARN
     :subnets - Vector of subnet IDs
     :security-groups - Vector of security group IDs
     :container-name - Name of container in task definition
     :env-overrides - Map of environment variable overrides {\"KEY\" \"value\"}
     :assign-public-ip - Whether to assign public IP (default true)"
  [{:keys [cluster task-definition subnets security-groups
           container-name env-overrides assign-public-ip]
    :or {assign-public-ip true}}]
  (let [env-pairs (when env-overrides
                    (mapv (fn [[k v]] {:name (name k) :value (str v)})
                          env-overrides))
        overrides (when (and container-name env-pairs)
                    {:containerOverrides
                     [{:name container-name
                       :environment env-pairs}]})
        request (cond-> {:cluster cluster
                         :taskDefinition task-definition
                         :launchType "FARGATE"
                         :networkConfiguration
                         {:awsvpcConfiguration
                          {:subnets subnets
                           :securityGroups security-groups
                           :assignPublicIp (if assign-public-ip "ENABLED" "DISABLED")}}}
                  overrides (assoc :overrides overrides))
        response (-> (aws/invoke @ecs-client
                                 {:op :RunTask
                                  :request request})
                     (check-error "RunTask"))]
    (first (:tasks response))))

(defn describe-tasks
  "Describe ECS tasks by their ARNs.
   Returns a vector of task descriptions."
  [cluster task-arns]
  (let [response (-> (aws/invoke @ecs-client
                                 {:op :DescribeTasks
                                  :request {:cluster cluster
                                            :tasks task-arns}})
                     (check-error "DescribeTasks"))]
    (:tasks response)))

(defn stop-task
  "Stop a running ECS task.
   Returns the stopped task description."
  [cluster task-arn reason]
  (let [response (-> (aws/invoke @ecs-client
                                 {:op :StopTask
                                  :request {:cluster cluster
                                            :task task-arn
                                            :reason reason}})
                     (check-error "StopTask"))]
    (:task response)))
