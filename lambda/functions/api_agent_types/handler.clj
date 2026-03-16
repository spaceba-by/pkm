(ns handler
  "API Lambda: CRUD for dispatch agent type configurations"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn- now-iso []
  (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS)))

(defn- format-agent-type
  "Format an agent type config for API response"
  [item]
  (cond-> {:name (:name item)
           :target (or (:target item) "ecs")
           :description (or (:description item) "")
           :created (r/truncate-timestamp (:created item))
           :updated (r/truncate-timestamp (:updated item))}
    (:ecs_task_definition item) (assoc :ecsTaskDefinition (:ecs_task_definition item))
    (:ecs_cluster item) (assoc :ecsCluster (:ecs_cluster item))
    (:ecs_subnets item) (assoc :ecsSubnets (:ecs_subnets item))
    (:ecs_security_groups item) (assoc :ecsSecurityGroups (:ecs_security_groups item))
    (:container_image item) (assoc :containerImage (:container_image item))
    (:container_name item) (assoc :containerName (:container_name item))
    (:cpu item) (assoc :cpu (:cpu item))
    (:memory item) (assoc :memory (:memory item))
    (:env_vars item) (assoc :envVars (:env_vars item))))

(defn- list-agent-types []
  (let [items (ddb/query ddb-table
                          :key-condition-expr "PK = :pk"
                          :expr-attr-values {":pk" "dispatch#agent-type"}
                          :limit 100)]
    (mapv format-agent-type items)))

(defn- create-agent-type [body]
  (let [type-name (or (:name body) (throw (ex-info "Missing name" {:type :validation})))
        target (or (:target body) "ecs")
        _ (when-not (#{"ecs" "local"} target)
            (throw (ex-info "Target must be 'ecs' or 'local'" {:type :validation})))
        now (now-iso)
        item (cond-> {:PK "dispatch#agent-type"
                       :SK (str "type#" type-name)
                       :name type-name
                       :target target
                       :description (or (:description body) "")
                       :created now
                       :updated now}
               ;; ECS-specific fields
               (:ecsTaskDefinition body) (assoc :ecs_task_definition (:ecsTaskDefinition body))
               (:ecsCluster body) (assoc :ecs_cluster (:ecsCluster body))
               (:ecsSubnets body) (assoc :ecs_subnets (:ecsSubnets body))
               (:ecsSecurityGroups body) (assoc :ecs_security_groups (:ecsSecurityGroups body))
               (:containerImage body) (assoc :container_image (:containerImage body))
               (:containerName body) (assoc :container_name (:containerName body))
               (:cpu body) (assoc :cpu (:cpu body))
               (:memory body) (assoc :memory (:memory body))
               (:envVars body) (assoc :env_vars (:envVars body)))]
    (ddb/put-item ddb-table item)
    (format-agent-type item)))

(defn- delete-agent-type [type-name]
  ;; Check for active jobs using this agent type
  (let [jobs (ddb/query ddb-table
                         :key-condition-expr "PK = :pk AND begins_with(SK, :sk_prefix)"
                         :expr-attr-values {":pk" "dispatch#job"
                                            ":sk_prefix" "job#"}
                         :limit 100)
        active-jobs (filter #(and (= type-name (:agent_type %))
                                   (#{"pending" "running"} (:status %)))
                            jobs)]
    (when (seq active-jobs)
      (throw (ex-info (str "Cannot delete agent type with " (count active-jobs)
                           " active job(s)")
                      {:type :conflict}))))
  (ddb/delete-item ddb-table {:PK "dispatch#agent-type"
                               :SK (str "type#" type-name)}))

(defn handler [request]
  (try
    (let [event (json/parse-string (:body request) true)
          admin-check (r/require-admin event)]
      (if admin-check
        admin-check
        (let [method (or (get-in event [:requestContext :http :method])
                         (get-in event ["requestContext" "http" "method"])
                         "GET")]
          (case method
            "GET"
            (r/ok {:agentTypes (list-agent-types)})

            "POST"
            (let [body (when-let [b (or (:body event) (get event "body"))]
                         (if (string? b) (json/parse-string b true) b))
                  result (create-agent-type body)]
              (r/created result))

            "DELETE"
            (let [path-params (r/parse-path-params event)
                  type-name (or (get path-params "name") (get path-params :name))]
              (when-not type-name
                (throw (ex-info "Missing agent type name" {:type :validation})))
              (delete-agent-type type-name)
              (r/no-content))

            (r/bad-request (str "Unsupported method: " method))))))

    (catch clojure.lang.ExceptionInfo e
      (let [data (ex-data e)]
        (case (:type data)
          :validation (r/bad-request (ex-message e))
          :conflict (r/conflict (ex-message e))
          (do
            (println "Error managing agent types:" (ex-message e))
            (r/internal-error "Failed to manage agent types")))))

    (catch Exception e
      (println "Error managing agent types:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to manage agent types"))))
