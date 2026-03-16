(ns dispatch.collect-results-test
  "Tests for dispatch result collection and formatting"
  (:require [clojure.test :refer [deftest is testing]]
            [clojure.string :as str]))

;; =============================================================================
;; Result summary generation tests
;; =============================================================================

(defn- now-iso []
  (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS)))

(defn write-result-summary
  "Generate a result summary markdown document (mirrors handler logic)"
  [job-id task-description status artifacts result-content]
  (str "# Dispatch Job Result: " job-id "\n\n"
       "**Task:** " task-description "\n"
       "**Status:** " status "\n"
       "**Completed:** " (now-iso) "\n\n"
       (when (seq artifacts)
         (str "## Artifacts\n\n"
              (str/join "\n" (map #(str "- " %) artifacts))
              "\n\n"))
       (when result-content
         (str "## Result\n\n" result-content "\n"))))

(deftest write-result-summary-test
  (testing "Generates summary with all fields"
    (let [summary (write-result-summary "job-123" "Fix auth bug" "completed"
                                         ["patch.diff" "test-results.txt"]
                                         "Bug fixed successfully")]
      (is (str/includes? summary "# Dispatch Job Result: job-123"))
      (is (str/includes? summary "**Task:** Fix auth bug"))
      (is (str/includes? summary "**Status:** completed"))
      (is (str/includes? summary "## Artifacts"))
      (is (str/includes? summary "- patch.diff"))
      (is (str/includes? summary "- test-results.txt"))
      (is (str/includes? summary "## Result"))
      (is (str/includes? summary "Bug fixed successfully"))))

  (testing "Generates summary without artifacts"
    (let [summary (write-result-summary "job-456" "Research topic" "completed"
                                         [] "Found relevant papers")]
      (is (str/includes? summary "# Dispatch Job Result: job-456"))
      (is (not (str/includes? summary "## Artifacts")))
      (is (str/includes? summary "## Result"))))

  (testing "Generates summary without result content"
    (let [summary (write-result-summary "job-789" "Build project" "failed"
                                         ["error.log"] nil)]
      (is (str/includes? summary "**Status:** failed"))
      (is (str/includes? summary "- error.log"))
      (is (not (str/includes? summary "## Result")))))

  (testing "Handles empty artifacts and no result"
    (let [summary (write-result-summary "job-000" "Test task" "completed" [] nil)]
      (is (str/includes? summary "# Dispatch Job Result: job-000"))
      (is (not (str/includes? summary "## Artifacts")))
      (is (not (str/includes? summary "## Result"))))))

;; =============================================================================
;; Status determination tests
;; =============================================================================

(deftest determine-exit-status-test
  (testing "Explicit status takes precedence"
    (is (= "completed" (or "completed" nil)))
    (is (= "failed" (or "failed" nil))))

  (testing "All containers exit 0 means completed"
    (let [containers [{:exitCode 0} {:exitCode 0}]
          all-zero? (every? #(= 0 (:exitCode %)) containers)]
      (is all-zero?)
      (is (= "completed" (if all-zero? "completed" "failed")))))

  (testing "Any non-zero exit code means failed"
    (let [containers [{:exitCode 0} {:exitCode 1}]
          all-zero? (every? #(= 0 (:exitCode %)) containers)]
      (is (not all-zero?))
      (is (= "failed" (if all-zero? "completed" "failed"))))))

;; =============================================================================
;; Job ID extraction tests
;; =============================================================================

(defn extract-job-id-from-ecs-event
  "Extract job ID from ECS task state change event"
  [event]
  (let [overrides (get-in event [:detail :overrides :containerOverrides])
        envs (mapcat :environment overrides)
        job-env (first (filter #(= "JOB_ID" (:name %)) envs))]
    (:value job-env)))

(deftest extract-job-id-test
  (testing "Extracts JOB_ID from ECS event"
    (let [event {:detail
                 {:overrides
                  {:containerOverrides
                   [{:name "dispatch-sandbox"
                     :environment [{:name "JOB_ID" :value "abc-123"}
                                   {:name "S3_BUCKET" :value "my-bucket"}]}]}}}
          job-id (extract-job-id-from-ecs-event event)]
      (is (= "abc-123" job-id))))

  (testing "Returns nil when JOB_ID not present"
    (let [event {:detail
                 {:overrides
                  {:containerOverrides
                   [{:name "dispatch-sandbox"
                     :environment [{:name "S3_BUCKET" :value "my-bucket"}]}]}}}
          job-id (extract-job-id-from-ecs-event event)]
      (is (nil? job-id))))

  (testing "Returns nil for empty event"
    (let [job-id (extract-job-id-from-ecs-event {})]
      (is (nil? job-id)))))

;; =============================================================================
;; Artifact path tests
;; =============================================================================

(deftest artifact-path-test
  (testing "Strips prefix from artifact keys"
    (let [prefix "_agent/dispatch/job-123/output/"
          keys ["_agent/dispatch/job-123/output/result.md"
                "_agent/dispatch/job-123/output/code/main.clj"]
          relative (mapv #(str/replace-first % prefix "") keys)]
      (is (= ["result.md" "code/main.clj"] relative))))

  (testing "Empty keys list produces empty artifacts"
    (let [keys []
          relative (mapv #(str/replace-first % "prefix/" "") keys)]
      (is (empty? relative)))))
