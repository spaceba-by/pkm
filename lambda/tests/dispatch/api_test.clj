(ns dispatch.api-test
  "Tests for dispatch API response formatting and validation"
  (:require [clojure.test :refer [deftest is testing]]
            [cheshire.core :as json])
  (:import [java.util Base64]))

;; =============================================================================
;; Cursor encode/decode tests
;; =============================================================================

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

(deftest cursor-roundtrip-test
  (testing "Encode and decode cursor roundtrip"
    (let [key {:PK "dispatch#job" :SK "job#abc-123"}
          encoded (encode-cursor key)
          decoded (decode-cursor encoded)]
      (is (= key decoded))))

  (testing "nil cursor encodes to nil"
    (is (nil? (encode-cursor nil))))

  (testing "nil cursor decodes to nil"
    (is (nil? (decode-cursor nil))))

  (testing "empty cursor decodes to nil"
    (is (nil? (decode-cursor "")))))

;; =============================================================================
;; Job formatting tests
;; =============================================================================

(defn format-job [job]
  (cond-> {:jobId (:job_id job)
           :status (:status job)
           :agentType (:agent_type job)
           :taskDescription (:task_description job)
           :created (:created job)
           :updated (:updated job)}
    (:context_paths job) (assoc :contextPaths (:context_paths job))
    (:started_at job) (assoc :startedAt (:started_at job))
    (:completed_at job) (assoc :completedAt (:completed_at job))
    (:error job) (assoc :error (:error job))
    (:artifacts job) (assoc :artifacts (:artifacts job))
    (:result_path job) (assoc :resultPath (:result_path job))
    (:ecs_task_arn job) (assoc :ecsTaskArn (:ecs_task_arn job))
    (:claimed_by job) (assoc :claimedBy (:claimed_by job))
    (:created_by job) (assoc :createdBy (:created_by job))))

(deftest format-job-test
  (testing "Formats complete job record"
    (let [job {:job_id "abc-123"
               :status "completed"
               :agent_type "code-review"
               :task_description "Review PR #42"
               :context_paths ["src/main.clj"]
               :created "2026-03-16T00:00:00Z"
               :updated "2026-03-16T01:00:00Z"
               :started_at "2026-03-16T00:01:00Z"
               :completed_at "2026-03-16T01:00:00Z"
               :artifacts ["review.md"]
               :result_path "_agent/dispatch/abc-123/result.md"
               :ecs_task_arn "arn:aws:ecs:us-east-1:123:task/abc"
               :created_by "user-1"}
          formatted (format-job job)]
      (is (= "abc-123" (:jobId formatted)))
      (is (= "completed" (:status formatted)))
      (is (= "code-review" (:agentType formatted)))
      (is (= "Review PR #42" (:taskDescription formatted)))
      (is (= ["src/main.clj"] (:contextPaths formatted)))
      (is (= "2026-03-16T00:01:00Z" (:startedAt formatted)))
      (is (= "2026-03-16T01:00:00Z" (:completedAt formatted)))
      (is (= ["review.md"] (:artifacts formatted)))
      (is (= "arn:aws:ecs:us-east-1:123:task/abc" (:ecsTaskArn formatted)))
      (is (= "user-1" (:createdBy formatted)))))

  (testing "Formats minimal job (pending, no optional fields)"
    (let [job {:job_id "def-456"
               :status "pending"
               :agent_type "local-dev"
               :task_description "Build project"
               :created "2026-03-16T00:00:00Z"
               :updated "2026-03-16T00:00:00Z"}
          formatted (format-job job)]
      (is (= "def-456" (:jobId formatted)))
      (is (= "pending" (:status formatted)))
      (is (not (contains? formatted :startedAt)))
      (is (not (contains? formatted :completedAt)))
      (is (not (contains? formatted :artifacts)))
      (is (not (contains? formatted :error)))
      (is (not (contains? formatted :ecsTaskArn)))))

  (testing "Includes error for failed jobs"
    (let [job {:job_id "ghi-789"
               :status "failed"
               :agent_type "code-review"
               :task_description "Deploy app"
               :created "2026-03-16T00:00:00Z"
               :updated "2026-03-16T00:05:00Z"
               :error "Container exited with code 1"}
          formatted (format-job job)]
      (is (= "failed" (:status formatted)))
      (is (= "Container exited with code 1" (:error formatted)))))

  (testing "Includes claimedBy for local jobs"
    (let [job {:job_id "jkl-012"
               :status "running"
               :agent_type "local-dev"
               :task_description "Research"
               :created "2026-03-16T00:00:00Z"
               :updated "2026-03-16T00:00:00Z"
               :claimed_by "local-agent-1"}
          formatted (format-job job)]
      (is (= "local-agent-1" (:claimedBy formatted))))))

;; =============================================================================
;; Agent type formatting tests
;; =============================================================================

(defn format-agent-type [item]
  (cond-> {:name (:name item)
           :target (or (:target item) "ecs")
           :description (or (:description item) "")}
    (:ecs_task_definition item) (assoc :ecsTaskDefinition (:ecs_task_definition item))
    (:ecs_cluster item) (assoc :ecsCluster (:ecs_cluster item))
    (:container_image item) (assoc :containerImage (:container_image item))
    (:cpu item) (assoc :cpu (:cpu item))
    (:memory item) (assoc :memory (:memory item))))

(deftest format-agent-type-test
  (testing "Formats ECS agent type"
    (let [item {:name "code-review"
                :target "ecs"
                :description "Code review agent"
                :ecs_task_definition "pkm-dispatch:1"
                :ecs_cluster "pkm-dispatch"
                :cpu 1024
                :memory 2048}
          formatted (format-agent-type item)]
      (is (= "code-review" (:name formatted)))
      (is (= "ecs" (:target formatted)))
      (is (= "pkm-dispatch:1" (:ecsTaskDefinition formatted)))
      (is (= 1024 (:cpu formatted)))))

  (testing "Formats local agent type"
    (let [item {:name "local-dev"
                :target "local"
                :description "Local development agent"}
          formatted (format-agent-type item)]
      (is (= "local-dev" (:name formatted)))
      (is (= "local" (:target formatted)))
      (is (not (contains? formatted :ecsTaskDefinition)))
      (is (not (contains? formatted :cpu)))))

  (testing "Defaults target to ecs when nil"
    (let [item {:name "default-agent"}
          formatted (format-agent-type item)]
      (is (= "ecs" (:target formatted))))))

;; =============================================================================
;; Status validation tests
;; =============================================================================

(def valid-job-statuses #{"pending" "running" "completed" "failed"})
(def valid-targets #{"ecs" "local"})

(deftest status-validation-test
  (testing "Valid job statuses are accepted"
    (doseq [status ["pending" "running" "completed" "failed"]]
      (is (contains? valid-job-statuses status)
          (str status " should be valid"))))

  (testing "Invalid job statuses are rejected"
    (doseq [status ["done" "cancelled" "queued" ""]]
      (is (not (contains? valid-job-statuses status))
          (str status " should be rejected")))))

(deftest target-validation-test
  (testing "Valid targets are accepted"
    (doseq [target ["ecs" "local"]]
      (is (contains? valid-targets target)
          (str target " should be valid"))))

  (testing "Invalid targets are rejected"
    (doseq [target ["lambda" "docker" "kubernetes" ""]]
      (is (not (contains? valid-targets target))
          (str target " should be rejected")))))

;; =============================================================================
;; Claim job logic tests
;; =============================================================================

(deftest claim-job-filtering-test
  (testing "Finds pending jobs matching agent types"
    (let [jobs [{:status "pending" :agent_type "code-review"}
                {:status "running" :agent_type "local-dev"}
                {:status "pending" :agent_type "local-dev"}
                {:status "completed" :agent_type "code-review"}]
          requested-types #{"local-dev" "research"}
          matching (filter #(and (= "pending" (:status %))
                                 (contains? requested-types (:agent_type %)))
                           jobs)]
      (is (= 1 (count matching)))
      (is (= "local-dev" (:agent_type (first matching))))))

  (testing "No pending jobs returns empty"
    (let [jobs [{:status "running" :agent_type "local-dev"}
                {:status "completed" :agent_type "local-dev"}]
          matching (filter #(= "pending" (:status %)) jobs)]
      (is (empty? matching))))

  (testing "No matching agent types returns empty"
    (let [jobs [{:status "pending" :agent_type "code-review"}]
          requested-types #{"local-dev"}
          matching (filter #(contains? requested-types (:agent_type %)) jobs)]
      (is (empty? matching)))))
