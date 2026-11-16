(ns workflows.triggers-test
  "Tests for workflow trigger matching, schedules and cooldowns"
  (:require [clojure.test :refer [deftest is testing]]
            [workflow.triggers :as triggers])
  (:import [java.time Instant]))

(def now (Instant/parse "2026-11-15T12:30:00Z")) ;; a Sunday

(defn- wf [overrides]
  (merge {:workflow_id "wf-1" :name "action-items" :enabled true
          :trigger {:type "document"} :filter {}}
         overrides))

(def meeting-doc
  {:document_path "meetings/2026-11-15 Planning.md"
   :tags ["Meeting" "q4"]
   :classification "meeting"
   :modified "2026-11-15T10:00:00Z"})

;; =============================================================================
;; matches-filter?
;; =============================================================================

(deftest matches-filter-test
  (testing "Empty filter matches everything"
    (is (triggers/matches-filter? {} meeting-doc))
    (is (triggers/matches-filter? nil meeting-doc)))

  (testing "Path prefix is case-sensitive"
    (is (triggers/matches-filter? {:path_prefix "meetings/"} meeting-doc))
    (is (not (triggers/matches-filter? {:path_prefix "Meetings/"} meeting-doc)))
    (is (not (triggers/matches-filter? {:path_prefix "projects/"} meeting-doc))))

  (testing "Tags match any listed tag, case-insensitively, with or without #"
    (is (triggers/matches-filter? {:tags ["#meeting"]} meeting-doc))
    (is (triggers/matches-filter? {:tags ["Q4" "nope"]} meeting-doc))
    (is (not (triggers/matches-filter? {:tags ["project-x"]} meeting-doc)))
    (is (not (triggers/matches-filter? {:tags ["meeting"]} (dissoc meeting-doc :tags)))))

  (testing "Classifications match one of the listed values"
    (is (triggers/matches-filter? {:classifications ["meeting" "project"]} meeting-doc))
    (is (not (triggers/matches-filter? {:classifications ["journal"]} meeting-doc)))
    (is (not (triggers/matches-filter? {:classifications ["meeting"]} (dissoc meeting-doc :classification)))))

  (testing "All conditions must hold"
    (is (triggers/matches-filter? {:path_prefix "meetings/" :tags ["q4"] :classifications ["meeting"]}
                                  meeting-doc))
    (is (not (triggers/matches-filter? {:path_prefix "meetings/" :tags ["q4"] :classifications ["idea"]}
                                       meeting-doc))))

  (testing "Accepts :path as well as :document_path"
    (is (triggers/matches-filter? {:path_prefix "a/"} {:path "a/b.md"}))))

;; =============================================================================
;; select-documents / lookback-since
;; =============================================================================

(deftest select-documents-test
  (testing "Filters, sorts newest first and caps the set"
    (let [docs (for [i (range 60)]
                 {:document_path (str "notes/" i ".md")
                  :classification (if (even? i) "idea" "journal")
                  :modified (format "2026-11-%02dT00:00:00Z" (inc (mod i 28)))})
          selected (triggers/select-documents {:classifications ["idea"]} docs)]
      (is (= 30 (count selected)))
      (is (every? #(= "idea" (:classification %)) selected))
      (is (= (map :modified selected) (reverse (sort (map :modified selected))))))
    (let [docs (for [i (range 80)] {:document_path (str "n/" i ".md") :modified "2026-11-01T00:00:00Z"})]
      (is (= triggers/max-set-documents (count (triggers/select-documents {} docs))))))

  (testing "Empty input gives empty set"
    (is (= [] (triggers/select-documents {:tags ["x"]} [])))))

(deftest lookback-since-test
  (is (= "2026-11-08T12:30:00Z" (triggers/lookback-since {} now)))
  (is (= "2026-11-14T12:30:00Z" (triggers/lookback-since {:lookback_days 1} now))))

;; =============================================================================
;; document-workflows / find-command-workflow / due-workflows
;; =============================================================================

(deftest document-workflows-test
  (let [workflows [(wf {:workflow_id "a" :filter {:classifications ["meeting"]}})
                   (wf {:workflow_id "b" :filter {:classifications ["journal"]}})
                   (wf {:workflow_id "c" :enabled false})
                   (wf {:workflow_id "d" :trigger {:type "schedule"}})
                   (wf {:workflow_id "e" :trigger {:type "command"} :name "x"})
                   (wf {:workflow_id "f"})]
        matched (triggers/document-workflows workflows meeting-doc)]
    (testing "Only enabled document workflows with a matching filter fire"
      (is (= ["a" "f"] (map :workflow_id matched))))))

(deftest find-command-workflow-test
  (let [workflows [(wf {:workflow_id "a" :name "research" :trigger {:type "command"}})
                   (wf {:workflow_id "b" :name "digest" :trigger {:type "command"} :enabled false})
                   (wf {:workflow_id "c" :name "notes" :trigger {:type "document"}})]]
    (testing "Finds by name, case-insensitively"
      (is (= "a" (:workflow_id (triggers/find-command-workflow workflows "research"))))
      (is (= "a" (:workflow_id (triggers/find-command-workflow workflows " Research ")))))
    (testing "Disabled, non-command, unknown and blank names return nil"
      (is (nil? (triggers/find-command-workflow workflows "digest")))
      (is (nil? (triggers/find-command-workflow workflows "notes")))
      (is (nil? (triggers/find-command-workflow workflows "missing")))
      (is (nil? (triggers/find-command-workflow workflows nil)))
      (is (nil? (triggers/find-command-workflow workflows ""))))))

(deftest due-workflows-test
  (let [sched (fn [id next-run & [enabled]]
                (wf {:workflow_id id :trigger {:type "schedule" :schedule {:frequency "daily" :hour 6}}
                     :next_run next-run :enabled (if (nil? enabled) true enabled)}))
        workflows [(sched "past" "2026-11-15T12:00:00Z")
                   (sched "exact" "2026-11-15T12:30:00Z")
                   (sched "future" "2026-11-15T13:00:00Z")
                   (sched "never-computed" nil)
                   (sched "disabled" "2026-11-15T00:00:00Z" false)
                   (wf {:workflow_id "doc" :next_run "2026-11-15T00:00:00Z"})]]
    (is (= ["past" "exact" "never-computed"]
           (map :workflow_id (triggers/due-workflows workflows now))))))

;; =============================================================================
;; Schedules
;; =============================================================================

(deftest validate-schedule-test
  (testing "Valid schedules"
    (is (= [] (triggers/validate-schedule {:frequency "hourly"})))
    (is (= [] (triggers/validate-schedule {:frequency "hourly" :minute 15})))
    (is (= [] (triggers/validate-schedule {:frequency "daily" :hour 6 :minute 0})))
    (is (= [] (triggers/validate-schedule {:frequency "weekly" :hour 9 :day_of_week "Monday"}))))

  (testing "Invalid schedules"
    (is (seq (triggers/validate-schedule nil)))
    (is (seq (triggers/validate-schedule {:frequency "monthly"})))
    (is (seq (triggers/validate-schedule {:frequency "hourly" :minute 60})))
    (is (seq (triggers/validate-schedule {:frequency "hourly" :minute "5"})))
    (is (seq (triggers/validate-schedule {:frequency "daily"})))
    (is (seq (triggers/validate-schedule {:frequency "daily" :hour 24})))
    (is (seq (triggers/validate-schedule {:frequency "weekly" :hour 9})))
    (is (seq (triggers/validate-schedule {:frequency "weekly" :hour 9 :day_of_week "someday"})))))

(deftest next-run-test
  ;; now is Sunday 2026-11-15T12:30:00Z
  (testing "Hourly picks the next matching minute"
    (is (= "2026-11-15T12:45:00Z" (triggers/next-run {:frequency "hourly" :minute 45} now)))
    (is (= "2026-11-15T13:15:00Z" (triggers/next-run {:frequency "hourly" :minute 15} now)))
    (is (= "2026-11-15T13:30:00Z" (triggers/next-run {:frequency "hourly" :minute 30} now)))
    (is (= "2026-11-15T13:00:00Z" (triggers/next-run {:frequency "hourly"} now))))

  (testing "Daily picks today if still ahead, else tomorrow"
    (is (= "2026-11-15T18:00:00Z" (triggers/next-run {:frequency "daily" :hour 18} now)))
    (is (= "2026-11-16T06:00:00Z" (triggers/next-run {:frequency "daily" :hour 6} now)))
    (is (= "2026-11-16T12:30:00Z" (triggers/next-run {:frequency "daily" :hour 12 :minute 30} now))))

  (testing "Weekly picks the next matching weekday"
    (is (= "2026-11-16T09:00:00Z" (triggers/next-run {:frequency "weekly" :hour 9 :day_of_week "monday"} now)))
    (is (= "2026-11-15T20:00:00Z" (triggers/next-run {:frequency "weekly" :hour 20 :day_of_week "sunday"} now)))
    (is (= "2026-11-22T06:00:00Z" (triggers/next-run {:frequency "weekly" :hour 6 :day_of_week "Sunday"} now)))
    (is (= "2026-11-16T00:00:00Z" (triggers/next-run {:frequency "weekly"} now))))

  (testing "Unknown frequency throws a validation error"
    (is (thrown? clojure.lang.ExceptionInfo (triggers/next-run {:frequency "monthly"} now)))))

;; =============================================================================
;; Cooldown
;; =============================================================================

(deftest in-cooldown-test
  (testing "Recent run within the window blocks"
    (is (triggers/in-cooldown? "2026-11-15T12:00:00Z" 60 now))
    (is (triggers/in-cooldown? "2026-11-15T11:31:00Z" 60 now)))

  (testing "Run at or beyond the window does not block"
    (is (not (triggers/in-cooldown? "2026-11-15T11:30:00Z" 60 now)))
    (is (not (triggers/in-cooldown? "2026-11-14T12:00:00Z" 60 now))))

  (testing "Nil last run, blank last run and zero cooldown never block"
    (is (not (triggers/in-cooldown? nil 60 now)))
    (is (not (triggers/in-cooldown? "" 60 now)))
    (is (not (triggers/in-cooldown? "2026-11-15T12:29:00Z" 0 now))))

  (testing "Nil cooldown uses the default"
    (is (triggers/in-cooldown? "2026-11-15T12:00:00Z" nil now))
    (is (not (triggers/in-cooldown? "2026-11-15T11:00:00Z" nil now)))))
