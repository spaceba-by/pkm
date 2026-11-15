(ns workflows.schema-test
  "Tests for workflow key layout, model resolution and record builders"
  (:require [clojure.test :refer [deftest is testing]]
            [clojure.string :as str]
            [workflow.schema :as schema]
            [workflow.engine :as engine]))

(def workflow
  {:workflow_id "wf-1" :name "action-items" :created_by "user-1"
   :prompt {:model "sonnet" :max_tokens 2000 :temperature 0.2}
   :output {:destination "s3"}})

(deftest keys-test
  (is (= {:PK "workflow#def" :SK "wf#wf-1"} (schema/definition-key "wf-1")))
  (is (= {:PK "workflow#run#wf-1" :SK "run#2026-11-15T12:00:00Z#r-1"}
         (schema/run-key "wf-1" "2026-11-15T12:00:00Z" "r-1")))
  (is (= {:PK "workflow#run#wf-1" :SK "doc#meetings/a.md"}
         (schema/cooldown-key "wf-1" "meetings/a.md")))
  (is (str/starts-with? (:SK (schema/run-key "wf-1" "t" "r")) schema/run-sk-prefix)))

(deftest resolve-model-id-test
  (let [env {"BEDROCK_HAIKU_MODEL_ID" "haiku-id" "BEDROCK_SONNET_MODEL_ID" "sonnet-id"}]
    (testing "Maps logical names"
      (is (= "haiku-id" (schema/resolve-model-id {:model "haiku"} env)))
      (is (= "sonnet-id" (schema/resolve-model-id {:model "sonnet"} env))))
    (testing "Defaults to haiku"
      (is (= "haiku-id" (schema/resolve-model-id {} env)))
      (is (= "haiku-id" (schema/resolve-model-id nil env))))
    (testing "Unknown model is a validation error"
      (is (= :validation (try (schema/resolve-model-id {:model "opus"} env)
                              (catch clojure.lang.ExceptionInfo e (:type (ex-data e)))))))
    (testing "Missing configuration is a config error"
      (is (= :config (try (schema/resolve-model-id {:model "sonnet"} {"BEDROCK_SONNET_MODEL_ID" ""})
                          (catch clojure.lang.ExceptionInfo e (:type (ex-data e)))))))))

(deftest invoke-options-test
  (testing "Applies defaults"
    (is (= {:max-tokens schema/default-max-tokens :temperature schema/default-temperature}
           (schema/invoke-options {} ""))))
  (testing "Caps max tokens and includes system prompt"
    (is (= {:max-tokens schema/max-max-tokens :temperature 0.1 :system "Be brief"}
           (schema/invoke-options {:max_tokens 999999 :temperature 0.1} "Be brief"))))
  (testing "Floors max tokens at 1 and drops blank system"
    (is (= 1 (:max-tokens (schema/invoke-options {:max_tokens 0} "   "))))
    (is (not (contains? (schema/invoke-options {} nil) :system)))))

(deftest run-record-test
  (testing "Single document run"
    (let [run (schema/run-record {:workflow workflow :run-id "r-1" :trigger "document"
                                  :document-path "meetings/a.md" :started "2026-11-15T12:00:00Z"})]
      (is (= "workflow#run#wf-1" (:PK run)))
      (is (= "run#2026-11-15T12:00:00Z#r-1" (:SK run)))
      (is (= "running" (:status run)))
      (is (= "action-items" (:workflow_name run)))
      (is (= "meetings/a.md" (:document_path run)))
      (is (not (contains? run :document_count)))))
  (testing "Set run"
    (let [run (schema/run-record {:workflow workflow :run-id "r-2" :trigger "schedule"
                                  :document-count 0 :started "t"})]
      (is (= 0 (:document_count run)))
      (is (not (contains? run :document_path))))))

(deftest completion-and-failure-attrs-test
  (testing "Completion includes usage and output key"
    (let [attrs (schema/completion-attrs {:completed "t" :duration-ms 1200 :model-id "m"
                                          :usage {:input_tokens 10 :output_tokens 20}
                                          :output-s3-key "_agent/x.md" :result "done"})]
      (is (= "completed" (:status attrs)))
      (is (= 10 (:input_tokens attrs)))
      (is (= 20 (:output_tokens attrs)))
      (is (= "_agent/x.md" (:output_s3_key attrs)))
      (is (= "done" (:result attrs)))))
  (testing "Completion without usage or key omits them"
    (let [attrs (schema/completion-attrs {:completed "t" :duration-ms 1 :model-id "m" :result nil})]
      (is (= "" (:result attrs)))
      (is (not (contains? attrs :input_tokens)))
      (is (not (contains? attrs :output_s3_key)))))
  (testing "Long results are truncated on the record"
    (let [long-result (apply str (repeat (+ schema/max-stored-result-chars 5000) "y"))
          attrs (schema/completion-attrs {:completed "t" :duration-ms 1 :model-id "m" :result long-result})]
      (is (< (count (:result attrs)) (count long-result)))
      (is (str/includes? (:result attrs) "truncated"))))
  (testing "Failure attrs"
    (is (= {:status "failed" :completed "t" :duration_ms 5 :error "boom"}
           (schema/failure-attrs {:completed "t" :duration-ms 5 :error "boom"})))
    (is (= "Unknown error" (:error (schema/failure-attrs {:completed "t" :duration-ms 5 :error nil}))))))

(deftest cooldown-record-test
  (let [rec (schema/cooldown-record "wf-1" "a/b.md" "r-1" "2026-11-15T12:00:00Z")]
    (is (= "workflow#run#wf-1" (:PK rec)))
    (is (= "doc#a/b.md" (:SK rec)))
    (is (= "2026-11-15T12:00:00Z" (:last_run rec)))
    (is (= "r-1" (:run_id rec)))))

(deftest notification-record-test
  (testing "Targets the creator and matches the notification_dispatch stream filter"
    (let [rec (schema/notification-record {:workflow workflow :run-id "r-1"
                                           :result "  Three action items found.  "
                                           :now "2026-11-15T12:00:00Z"})]
      (is (= "user#user-1" (:PK rec)))
      (is (str/starts-with? (:SK rec) "notification#pending#2026-11-15T12:00:00Z#"))
      (is (= "workflow" (:notification_type rec)))
      (is (= "Workflow: action-items" (:title rec)))
      (is (= "Three action items found." (:body rec)))
      (is (= "/workflows/wf-1/runs/r-1" (:deep_link rec)))
      (is (false? (:read rec)))
      (is (string? (:notification_id rec)))))
  (testing "Body is truncated"
    (let [rec (schema/notification-record {:workflow workflow :run-id "r"
                                           :result (apply str (repeat 1000 "z")) :now "t"})]
      (is (= (inc schema/max-notification-body-chars) (count (:body rec)))))))

(deftest output-path-template-test
  (is (= engine/default-output-path (schema/output-path-template {})))
  (is (= engine/default-output-path (schema/output-path-template {:output {:path "  "}})))
  (is (= "_agent/actions/{{document.title}}.md"
         (schema/output-path-template {:output {:path "_agent/actions/{{document.title}}.md"}}))))

(deftest format-run-test
  (testing "Formats a completed run"
    (let [run {:run_id "r-1" :workflow_id "wf-1" :workflow_name "w" :trigger "document"
               :status "completed" :started "s" :completed "c" :duration_ms 10
               :document_path "a.md" :model_id "m" :input_tokens 1 :output_tokens 2
               :output_s3_key "_agent/x.md" :result "ok"}
          f (schema/format-run run)]
      (is (= "r-1" (:runId f)))
      (is (= "wf-1" (:workflowId f)))
      (is (= "a.md" (:documentPath f)))
      (is (= 10 (:durationMs f)))
      (is (= 1 (:inputTokens f)))
      (is (= "_agent/x.md" (:outputS3Key f)))
      (is (= "ok" (:result f)))
      (is (not (contains? f :error)))))
  (testing "Formats a minimal running run"
    (let [f (schema/format-run {:run_id "r" :workflow_id "w" :workflow_name "n" :trigger "manual"
                                :status "running" :started "s" :document_count 0})]
      (is (= 0 (:documentCount f)))
      (is (not (contains? f :completed)))
      (is (not (contains? f :documentPath)))))
  (testing "Includes error for failed runs"
    (is (= "boom" (:error (schema/format-run {:run_id "r" :status "failed" :error "boom"}))))))
