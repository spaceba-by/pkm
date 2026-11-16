(ns workflows.api-test
  "Tests for workflow definition validation, API body conversion and formatting"
  (:require [clojure.test :refer [deftest is testing]]
            [clojure.string :as str]
            [workflow.schema :as schema]))

(def valid-body
  {:name "action-items"
   :description "Extract action items from meetings"
   :enabled true
   :trigger {:type "document"}
   :filter {:classifications ["meeting"] :tags ["#work"] :pathPrefix "meetings/"}
   :prompt {:system "You extract action items."
            :user "Extract action items from {{document.title}}:\n{{document.body}}"
            :model "haiku"
            :maxTokens 1000
            :temperature 0.2}
   :output {:destination "s3" :path "_agent/actions/{{document.title}}.md"}
   :cooldownMinutes 30})

(defn- definition [body]
  (-> body schema/body->definition schema/apply-defaults))

(defn- errors [body & [other-names]]
  (schema/validate-definition (definition body) other-names))

;; =============================================================================
;; body->definition / apply-defaults
;; =============================================================================

(deftest body->definition-test
  (testing "Converts camelCase to snake_case, nested included"
    (let [d (schema/body->definition
             (assoc valid-body :trigger {:type "schedule"
                                         :schedule {:frequency "weekly" :hour 6 :minute 30 :dayOfWeek "monday"}}
                    :filter {:lookbackDays 14 :pathPrefix "p/"}))]
      (is (= "action-items" (:name d)))
      (is (= 30 (:cooldown_minutes d)))
      (is (= {:type "schedule" :schedule {:frequency "weekly" :hour 6 :minute 30 :day_of_week "monday"}}
             (:trigger d)))
      (is (= {:lookback_days 14 :path_prefix "p/"} (:filter d)))
      (is (= 1000 (get-in d [:prompt :max_tokens])))
      (is (= "_agent/actions/{{document.title}}.md" (get-in d [:output :path])))))

  (testing "Only present keys are carried, so partial updates stay partial"
    (is (= {:enabled false} (schema/body->definition {:enabled false})))
    (is (= {:prompt {:user "x"}} (schema/body->definition {:prompt {:user "x"}})))
    (is (= {} (schema/body->definition {:unknown 1})))
    (is (= {} (schema/body->definition nil)))))

(deftest apply-defaults-test
  (let [d (schema/apply-defaults {:name "n" :trigger {:type "manual"} :prompt {:user "u"}})]
    (is (= "" (:description d)))
    (is (true? (:enabled d)))
    (is (= 60 (:cooldown_minutes d)))
    (is (= {} (:filter d)))
    (is (= {:user "u" :model "haiku" :max_tokens 4096 :temperature 0.7} (:prompt d)))
    (is (= {:destination "s3"} (:output d))))
  (testing "Explicit values win over defaults"
    (let [d (schema/apply-defaults {:enabled false :prompt {:user "u" :model "sonnet"}})]
      (is (false? (:enabled d)))
      (is (= "sonnet" (get-in d [:prompt :model]))))))

;; =============================================================================
;; validate-definition
;; =============================================================================

(deftest validate-valid-definitions-test
  (is (= [] (errors valid-body)))
  (is (= [] (errors {:name "digest" :trigger {:type "schedule" :schedule {:frequency "daily" :hour 6}}
                     :prompt {:user "Summarize {{documents.content}}"}})))
  (is (= [] (errors {:name "research" :trigger {:type "command"}
                     :prompt {:user "Research {{command.args}}"}
                     :output {:destination "notification"}})))
  (is (= [] (errors {:name "manual-1" :trigger {:type "manual"} :prompt {:user "x"}
                     :output {:destination "dynamodb"}}))))

(defn- has-error? [errs fragment]
  (boolean (some #(str/includes? % fragment) errs)))

(deftest validate-name-test
  (is (has-error? (errors (dissoc valid-body :name)) "name is required"))
  (is (has-error? (errors (assoc valid-body :name "Bad Name")) "name must be"))
  (is (has-error? (errors (assoc valid-body :name "-x")) "name must be"))
  (is (has-error? (errors (assoc valid-body :name "a")) "name must be"))
  (is (has-error? (errors valid-body #{"Action-Items"}) "already in use"))
  (is (= [] (errors valid-body #{"other"}))))

(deftest validate-trigger-test
  (is (has-error? (errors (dissoc valid-body :trigger)) "trigger is required"))
  (is (has-error? (errors (assoc valid-body :trigger {:type "webhook"})) "trigger.type must be"))
  (is (has-error? (errors (assoc valid-body :trigger {:type "schedule"})) "trigger.schedule"))
  (is (has-error? (errors (assoc valid-body :trigger {:type "schedule" :schedule {:frequency "daily"}}))
                  "hour")))

(deftest validate-filter-test
  (is (has-error? (errors (assoc valid-body :filter {:tags "work"})) "filter.tags"))
  (is (has-error? (errors (assoc valid-body :filter {:classifications ["memo"]})) "unknown value: memo"))
  (is (has-error? (errors (assoc valid-body :filter {:lookbackDays 0})) "filter.lookbackDays"))
  (is (has-error? (errors (assoc valid-body :filter {:lookbackDays 365})) "filter.lookbackDays"))
  (is (has-error? (errors (assoc valid-body :filter {:pathPrefix 5})) "filter.pathPrefix"))
  (is (= [] (errors (assoc valid-body :filter {})))))

(deftest validate-prompt-test
  (is (has-error? (errors (dissoc valid-body :prompt)) "prompt.user is required"))
  (is (has-error? (errors (assoc valid-body :prompt {:user "  "})) "prompt.user is required"))
  (is (has-error? (errors (assoc valid-body :prompt {:user "{{nope.x}}"})) "prompt.user: Unknown"))
  (is (has-error? (errors (assoc valid-body :prompt {:user "ok" :system "{{document.title"})) "prompt.system"))
  (is (has-error? (errors (assoc valid-body :prompt {:user "ok" :model "opus"})) "prompt.model"))
  (is (has-error? (errors (assoc valid-body :prompt {:user "ok" :maxTokens 0})) "prompt.maxTokens"))
  (is (has-error? (errors (assoc valid-body :prompt {:user "ok" :maxTokens 50000})) "prompt.maxTokens"))
  (is (has-error? (errors (assoc valid-body :prompt {:user "ok" :temperature 1.5})) "prompt.temperature")))

(deftest validate-output-test
  (is (has-error? (errors (assoc valid-body :output {:destination "email"})) "output.destination"))
  (is (has-error? (errors (assoc valid-body :output {:path "notes/{{document.title}}.md"})) "must start with _agent/"))
  (is (has-error? (errors (assoc valid-body :output {:path "{{document.path}}"})) "must start with _agent/"))
  (is (has-error? (errors (assoc valid-body :output {:path "_agent/{{bogus.x}}.md"})) "output.path: Unknown"))
  (is (= [] (errors (assoc valid-body :output {:path ""})))))

(deftest validate-misc-test
  (is (has-error? (errors (assoc valid-body :enabled "yes")) "enabled must be"))
  (is (has-error? (errors (assoc valid-body :cooldownMinutes -1)) "cooldownMinutes"))
  (is (has-error? (errors (assoc valid-body :cooldownMinutes 99999)) "cooldownMinutes"))
  (testing "Multiple errors are all reported"
    (is (<= 3 (count (errors {:name "!" :trigger {:type "x"} :prompt {}}))))))

;; =============================================================================
;; format-definition
;; =============================================================================

(deftest format-definition-test
  (testing "Full item"
    (let [item (merge (definition (assoc valid-body
                                         :trigger {:type "schedule"
                                                   :schedule {:frequency "weekly" :hour 6 :dayOfWeek "monday"}}
                                         :filter {:lookbackDays 7}))
                      {:workflow_id "wf-1" :created "c" :updated "u" :created_by "user-1"
                       :next_run "n" :last_run "l" :last_status "completed" :run_count 3})
          f (schema/format-definition item)]
      (is (= "wf-1" (:id f)))
      (is (= "action-items" (:name f)))
      (is (true? (:enabled f)))
      (is (= {:type "schedule" :schedule {:frequency "weekly" :hour 6 :dayOfWeek "monday"}} (:trigger f)))
      (is (= {:lookbackDays 7} (:filter f)))
      (is (= {:system "You extract action items."
              :user "Extract action items from {{document.title}}:\n{{document.body}}"
              :model "haiku" :maxTokens 1000 :temperature 0.2}
             (:prompt f)))
      (is (= {:destination "s3" :path "_agent/actions/{{document.title}}.md"} (:output f)))
      (is (= 30 (:cooldownMinutes f)))
      (is (= 3 (:runCount f)))
      (is (= "n" (:nextRun f)))
      (is (= "l" (:lastRun f)))
      (is (= "completed" (:lastStatus f)))
      (is (= "user-1" (:createdBy f)))))

  (testing "Minimal item fills defaults and omits absent optionals"
    (let [f (schema/format-definition {:workflow_id "w" :name "n" :trigger {:type "manual"}
                                       :prompt {:user "u"}})]
      (is (= "" (:description f)))
      (is (false? (:enabled f)))
      (is (= {} (:filter f)))
      (is (= {:user "u" :model "haiku" :maxTokens 4096 :temperature 0.7} (:prompt f)))
      (is (= {:destination "s3"} (:output f)))
      (is (= 60 (:cooldownMinutes f)))
      (is (= 0 (:runCount f)))
      (is (not (contains? f :nextRun)))
      (is (not (contains? f :createdBy)))))

  (testing "Round trip through body->definition keeps the shape"
    (let [f (schema/format-definition (merge (definition valid-body) {:workflow_id "x"}))]
      (is (= (:filter valid-body) (update (:filter f) :tags vec)))
      (is (= (:output valid-body) (:output f))))))
