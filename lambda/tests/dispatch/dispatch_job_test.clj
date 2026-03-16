(ns dispatch.dispatch-job-test
  "Tests for dispatch job creation and formatting"
  (:require [clojure.test :refer [deftest is testing]]
            [cheshire.core :as json]))

;; =============================================================================
;; Job record creation tests
;; =============================================================================

(defn- now-iso []
  (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS)))

(defn create-job-record
  "Create a job record map (mirrors handler logic)"
  [job-id agent-type-name task-description context-paths created-by]
  (let [now (now-iso)]
    {:PK "dispatch#job"
     :SK (str "job#" job-id)
     :job_id job-id
     :status "pending"
     :agent_type agent-type-name
     :task_description task-description
     :context_paths (or context-paths [])
     :created now
     :updated now
     :created_by (or created-by "system")}))

(deftest create-job-record-test
  (testing "Creates job record with correct PK/SK pattern"
    (let [job (create-job-record "abc-123" "code-review" "Review PR #42" ["src/main.clj"] "user-1")]
      (is (= "dispatch#job" (:PK job)))
      (is (= "job#abc-123" (:SK job)))
      (is (= "abc-123" (:job_id job)))
      (is (= "pending" (:status job)))
      (is (= "code-review" (:agent_type job)))
      (is (= "Review PR #42" (:task_description job)))
      (is (= ["src/main.clj"] (:context_paths job)))
      (is (= "user-1" (:created_by job)))))

  (testing "Defaults created_by to system when nil"
    (let [job (create-job-record "def-456" "local-dev" "Build project" nil nil)]
      (is (= "system" (:created_by job)))
      (is (= [] (:context_paths job)))))

  (testing "Job ID is included in SK"
    (let [job-id "test-uuid-789"
          job (create-job-record job-id "research" "Find docs" nil nil)]
      (is (= (str "job#" job-id) (:SK job))))))

;; =============================================================================
;; Job input context tests
;; =============================================================================

(defn create-job-input
  "Create S3 input context payload"
  [task-description context-paths]
  {:task_description task-description
   :context_paths (or context-paths [])
   :created_at (now-iso)})

(deftest create-job-input-test
  (testing "Creates input with task description and context paths"
    (let [input (create-job-input "Fix bug in auth" ["src/auth.clj" "src/middleware.clj"])]
      (is (= "Fix bug in auth" (:task_description input)))
      (is (= ["src/auth.clj" "src/middleware.clj"] (:context_paths input)))
      (is (some? (:created_at input)))))

  (testing "Serializes to valid JSON"
    (let [input (create-job-input "Generate report" nil)
          json-str (json/generate-string input)]
      (is (string? json-str))
      (let [parsed (json/parse-string json-str true)]
        (is (= "Generate report" (:task_description parsed)))
        (is (= [] (:context_paths parsed)))))))

;; =============================================================================
;; Job ID resolution tests
;; =============================================================================

(deftest job-id-resolution-test
  (testing "Uses provided job_id when present"
    (let [payload {:job_id "provided-id" :job_id_hint "hint-id"}
          resolved (or (:job_id payload) (:job_id_hint payload) (str (java.util.UUID/randomUUID)))]
      (is (= "provided-id" resolved))))

  (testing "Falls back to job_id_hint when job_id is nil"
    (let [payload {:job_id_hint "hint-id"}
          resolved (or (:job_id payload) (:job_id_hint payload) (str (java.util.UUID/randomUUID)))]
      (is (= "hint-id" resolved))))

  (testing "Generates UUID when no ID provided"
    (let [payload {}
          resolved (or (:job_id payload) (:job_id_hint payload) (str (java.util.UUID/randomUUID)))]
      (is (some? resolved))
      (is (uuid? (java.util.UUID/fromString resolved))))))

;; =============================================================================
;; Agent type config validation tests
;; =============================================================================

(def sample-ecs-agent-type
  {:PK "dispatch#agent-type"
   :SK "type#code-review"
   :name "code-review"
   :target "ecs"
   :description "Code review agent with read-only repo access"
   :ecs_cluster "pkm-dispatch"
   :ecs_task_definition "pkm-dispatch-sandbox:1"
   :ecs_subnets ["subnet-abc123"]
   :ecs_security_groups ["sg-abc123"]
   :container_name "dispatch-sandbox"})

(def sample-local-agent-type
  {:PK "dispatch#agent-type"
   :SK "type#local-dev"
   :name "local-dev"
   :target "local"
   :description "Local development agent with private repo access"})

(deftest agent-type-target-test
  (testing "ECS agent type has target=ecs"
    (is (= "ecs" (:target sample-ecs-agent-type))))

  (testing "Local agent type has target=local"
    (is (= "local" (:target sample-local-agent-type))))

  (testing "ECS agent type has required infrastructure fields"
    (is (some? (:ecs_cluster sample-ecs-agent-type)))
    (is (some? (:ecs_task_definition sample-ecs-agent-type)))
    (is (seq (:ecs_subnets sample-ecs-agent-type)))
    (is (seq (:ecs_security_groups sample-ecs-agent-type)))))

;; =============================================================================
;; Dispatch target determination tests
;; =============================================================================

(deftest dispatch-target-test
  (testing "ECS agent type dispatches immediately"
    (let [config sample-ecs-agent-type
          target (:target config)]
      (is (= "ecs" target))
      ;; ECS jobs should be set to running after launch
      (is (= "running" (if (= target "ecs") "running" "pending")))))

  (testing "Local agent type stays pending"
    (let [config sample-local-agent-type
          target (:target config)]
      (is (= "local" target))
      ;; Local jobs remain pending until claimed
      (is (= "pending" (if (= target "ecs") "running" "pending"))))))

;; =============================================================================
;; S3 path construction tests
;; =============================================================================

(deftest s3-path-test
  (testing "Input path follows convention"
    (let [job-id "test-123"
          input-path (str "_agent/dispatch/" job-id "/input.json")]
      (is (= "_agent/dispatch/test-123/input.json" input-path))))

  (testing "Output path follows convention"
    (let [job-id "test-123"
          output-path (str "_agent/dispatch/" job-id "/output/")]
      (is (= "_agent/dispatch/test-123/output/" output-path))))

  (testing "Result path follows convention"
    (let [job-id "test-123"
          result-path (str "_agent/dispatch/" job-id "/result.md")]
      (is (= "_agent/dispatch/test-123/result.md" result-path)))))
