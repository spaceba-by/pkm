(ns persistent-search.api-test
  "Unit tests for persistent search API handler formatting and validation.

   Note: Functions are duplicated here rather than imported from handler
   namespaces because all Lambda handlers use the same 'handler' namespace
   name (required by the Lambda runtime)."
  (:require [clojure.test :refer [deftest is testing]]
            [clojure.string :as str]))

;; =============================================================================
;; Duplicated from api_search_monitors handler
;; =============================================================================

(def valid-statuses #{"active" "paused"})
(def min-interval-hours 1)
(def max-interval-hours 168)

(defn- user-pk [user-sub]
  (str "user#" user-sub))

(defn- monitor-sk [monitor-id]
  (str "search_monitor#" monitor-id "#CONFIG"))

(defn- format-monitor
  "Format a monitor record for API response"
  [monitor]
  {:id (:monitor_id monitor)
   :name (:name monitor)
   :description (:description monitor)
   :searchTerms (:search_terms monitor)
   :intervalHours (:interval_hours monitor)
   :noveltyThreshold (:novelty_threshold monitor)
   :status (:monitor_status monitor)
   :lastExecuted (:last_executed monitor)
   :nextExecution (:next_execution monitor)
   :created (:created monitor)
   :modified (:modified monitor)})

;; Duplicated from api_search_summaries handler
(defn- format-summary
  "Format a summary record for API response"
  [summary viewed-set]
  {:timestamp (:timestamp summary)
   :summary (:summary_text summary)
   :topics (or (:topics summary) [])
   :noveltyScore (:novelty_score summary)
   :significantUpdate (:significant_update summary)
   :newItems (or (:new_items summary) [])
   :changedItems (or (:changed_items summary) [])
   :removedItems (or (:removed_items summary) [])
   :analysis (:analysis summary)
   :viewed (boolean (get viewed-set (:timestamp summary)))})

;; =============================================================================
;; Key schema tests
;; =============================================================================

(deftest user-pk-test
  (testing "Generates correct user partition key"
    (is (= "user#abc-123" (user-pk "abc-123")))
    (is (= "user#test-user-sub" (user-pk "test-user-sub")))))

(deftest monitor-sk-test
  (testing "Generates correct monitor sort key"
    (is (= "search_monitor#mon-1#CONFIG" (monitor-sk "mon-1")))
    (is (str/starts-with? (monitor-sk "xyz") "search_monitor#"))
    (is (str/ends-with? (monitor-sk "xyz") "#CONFIG"))))

;; =============================================================================
;; format-monitor tests
;; =============================================================================

(deftest format-monitor-test
  (testing "Formats complete monitor record"
    (let [monitor {:monitor_id "mon-123"
                   :name "AI Research"
                   :description "Track AI developments"
                   :search_terms ["GPT" "Claude" "LLM"]
                   :interval_hours 6
                   :novelty_threshold 0.3
                   :monitor_status "active"
                   :last_executed "2026-02-17T06:00:00Z"
                   :next_execution "2026-02-17T12:00:00Z"
                   :created "2026-02-01T00:00:00Z"
                   :modified "2026-02-17T06:00:00Z"}
          result (format-monitor monitor)]
      (is (= "mon-123" (:id result)))
      (is (= "AI Research" (:name result)))
      (is (= "Track AI developments" (:description result)))
      (is (= ["GPT" "Claude" "LLM"] (:searchTerms result)))
      (is (= 6 (:intervalHours result)))
      (is (= 0.3 (:noveltyThreshold result)))
      (is (= "active" (:status result)))
      (is (= "2026-02-17T06:00:00Z" (:lastExecuted result)))
      (is (= "2026-02-17T12:00:00Z" (:nextExecution result)))))

  (testing "Handles nil fields"
    (let [monitor {:monitor_id "mon-456"
                   :name "Test"
                   :monitor_status "paused"}
          result (format-monitor monitor)]
      (is (= "mon-456" (:id result)))
      (is (= "Test" (:name result)))
      (is (nil? (:description result)))
      (is (nil? (:searchTerms result)))
      (is (nil? (:intervalHours result)))
      (is (= "paused" (:status result))))))

;; =============================================================================
;; format-summary tests
;; =============================================================================

(deftest format-summary-test
  (testing "Formats complete summary record"
    (let [summary {:timestamp "2026-02-17T12:00:00Z"
                   :summary_text "Key findings about AI..."
                   :topics ["AI" "machine learning"]
                   :novelty_score 0.75
                   :significant_update true
                   :new_items ["New discovery" "New paper"]
                   :changed_items ["Updated model"]
                   :removed_items ["Deprecated API"]
                   :analysis "Significant changes detected"}
          result (format-summary summary #{"2026-02-17T12:00:00Z"})]
      (is (= "2026-02-17T12:00:00Z" (:timestamp result)))
      (is (= "Key findings about AI..." (:summary result)))
      (is (= ["AI" "machine learning"] (:topics result)))
      (is (= 0.75 (:noveltyScore result)))
      (is (true? (:significantUpdate result)))
      (is (= ["New discovery" "New paper"] (:newItems result)))
      (is (= ["Updated model"] (:changedItems result)))
      (is (= ["Deprecated API"] (:removedItems result)))
      (is (= "Significant changes detected" (:analysis result)))
      (is (true? (:viewed result)))))

  (testing "Provides defaults for missing list fields"
    (let [summary {:timestamp "2026-02-17T00:00:00Z"
                   :summary_text "Minimal summary"
                   :novelty_score 0.0}
          result (format-summary summary #{})]
      (is (= [] (:topics result)))
      (is (= [] (:newItems result)))
      (is (= [] (:changedItems result)))
      (is (= [] (:removedItems result)))
      (is (false? (:viewed result))))))

;; =============================================================================
;; Validation tests
;; =============================================================================

(deftest validation-test
  (testing "Valid statuses"
    (is (contains? valid-statuses "active"))
    (is (contains? valid-statuses "paused"))
    (is (not (contains? valid-statuses "deleted")))
    (is (not (contains? valid-statuses "running"))))

  (testing "Interval bounds"
    (is (= 1 min-interval-hours))
    (is (= 168 max-interval-hours))
    (is (<= min-interval-hours 6))
    (is (>= max-interval-hours 6))))

;; =============================================================================
;; DynamoDB key design tests
;; =============================================================================

(deftest key-design-test
  (testing "CONFIG sort key for monitors"
    (let [sk (monitor-sk "abc-123")]
      (is (= "search_monitor#abc-123#CONFIG" sk))
      (is (str/starts-with? sk "search_monitor#"))))

  (testing "Snapshot sort key pattern"
    (let [sk (str "search_monitor#abc-123#snapshot#2026-02-17T12:00:00Z")]
      (is (str/starts-with? sk "search_monitor#abc-123#snapshot#"))))

  (testing "Summary sort key pattern"
    (let [sk (str "search_monitor#abc-123#summary#2026-02-17T12:00:00Z")]
      (is (str/starts-with? sk "search_monitor#abc-123#summary#"))))

  (testing "Notification sort key pattern"
    (let [sk (str "notification#pending#2026-02-17T12:00:00Z#notif-id")]
      (is (str/starts-with? sk "notification#pending#"))))

  (testing "begins_with queries work with key structure"
    (let [config-sk "search_monitor#mon1#CONFIG"
          snapshot-sk "search_monitor#mon1#snapshot#2026-01-01"
          summary-sk "search_monitor#mon1#summary#2026-01-01"
          prefix "search_monitor#mon1#"]
      ;; All three should match the monitor prefix
      (is (str/starts-with? config-sk prefix))
      (is (str/starts-with? snapshot-sk prefix))
      (is (str/starts-with? summary-sk prefix))

      ;; CONFIG filter
      (is (str/ends-with? config-sk "#CONFIG"))
      (is (not (str/ends-with? snapshot-sk "#CONFIG")))
      (is (not (str/ends-with? summary-sk "#CONFIG"))))))
