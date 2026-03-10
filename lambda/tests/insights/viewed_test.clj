(ns insights.viewed-test
  "Unit tests for insight viewed-status logic"
  (:require [clojure.test :refer [deftest testing is]]))

;; =============================================================================
;; is-viewed? logic (shared across api_list_summaries, api_list_reports,
;; api_insights_count, api_mark_viewed, notification_dispatch)
;; =============================================================================

(defn is-viewed?
  "Check if an insight record has been viewed (viewed_at >= modified_at)"
  [item]
  (let [viewed-at (:viewed_at item)
        modified-at (:modified_at item)]
    (and (some? viewed-at)
         (not (pos? (compare modified-at viewed-at))))))

(defn is-unviewed?
  "Check if an insight record is unviewed"
  [item]
  (let [viewed-at (:viewed_at item)
        modified-at (:modified_at item)]
    (or (nil? viewed-at)
        (pos? (compare modified-at viewed-at)))))

(deftest is-viewed-no-viewed-at-test
  (testing "Item without viewed_at is not viewed"
    (is (not (is-viewed? {:SK "summary#2026-03-08"
                          :modified_at "2026-03-08T06:00:00Z"})))
    (is (is-unviewed? {:SK "summary#2026-03-08"
                       :modified_at "2026-03-08T06:00:00Z"}))))

(deftest is-viewed-with-viewed-at-test
  (testing "Item with viewed_at >= modified_at is viewed"
    (is (is-viewed? {:SK "summary#2026-03-08"
                     :modified_at "2026-03-08T06:00:00Z"
                     :viewed_at "2026-03-08T12:00:00Z"}))
    (is (not (is-unviewed? {:SK "summary#2026-03-08"
                            :modified_at "2026-03-08T06:00:00Z"
                            :viewed_at "2026-03-08T12:00:00Z"})))))

(deftest is-viewed-same-timestamp-test
  (testing "Item with viewed_at == modified_at is viewed"
    (is (is-viewed? {:SK "report#2026-W10"
                     :modified_at "2026-03-08T06:00:00Z"
                     :viewed_at "2026-03-08T06:00:00Z"}))))

(deftest is-viewed-regenerated-test
  (testing "Regenerated item (modified_at > viewed_at) is unviewed"
    (is (not (is-viewed? {:SK "summary#2026-03-08"
                          :modified_at "2026-03-09T06:00:00Z"
                          :viewed_at "2026-03-08T12:00:00Z"})))
    (is (is-unviewed? {:SK "summary#2026-03-08"
                       :modified_at "2026-03-09T06:00:00Z"
                       :viewed_at "2026-03-08T12:00:00Z"}))))

(deftest count-unviewed-test
  (testing "Counting unviewed items from a list"
    (let [items [{:SK "summary#2026-03-08"
                  :modified_at "2026-03-08T06:00:00Z"}
                 {:SK "summary#2026-03-07"
                  :modified_at "2026-03-07T06:00:00Z"
                  :viewed_at "2026-03-07T12:00:00Z"}
                 {:SK "report#2026-W10"
                  :modified_at "2026-03-03T06:00:00Z"}
                 {:SK "search#abc#2026-03-08T12:00:00Z"
                  :modified_at "2026-03-08T12:00:00Z"
                  :viewed_at "2026-03-08T13:00:00Z"}
                 {:SK "summary#2026-03-06"
                  :modified_at "2026-03-07T00:00:00Z"
                  :viewed_at "2026-03-06T12:00:00Z"}]]
      ;; Unviewed: summary#2026-03-08 (no viewed_at),
      ;;           report#2026-W10 (no viewed_at),
      ;;           summary#2026-03-06 (regenerated: modified > viewed)
      ;; Viewed: summary#2026-03-07, search#abc
      (is (= 3 (count (filter is-unviewed? items))))
      (is (= 2 (count (filter is-viewed? items)))))))

;; =============================================================================
;; Insight record structure tests
;; =============================================================================

(deftest insight-sk-format-test
  (testing "Summary SK format"
    (let [date "2026-03-08"
          sk (str "summary#" date)]
      (is (= "summary#2026-03-08" sk))
      (is (= date (subs sk (count "summary#"))))))

  (testing "Report SK format"
    (let [week "2026-W10"
          sk (str "report#" week)]
      (is (= "report#2026-W10" sk))
      (is (= week (subs sk (count "report#"))))))

  (testing "Search update SK format"
    (let [monitor-id "abc123"
          timestamp "2026-03-08T12:00:00Z"
          sk (str "search#" monitor-id "#" timestamp)]
      (is (= "search#abc123#2026-03-08T12:00:00Z" sk)))))

(deftest insight-record-structure-test
  (testing "Daily summary insight record has required fields"
    (let [record {:PK "insight#test-user-sub"
                  :SK "summary#2026-03-08"
                  :type "daily_summary"
                  :title "Daily Summary: 2026-03-08"
                  :modified_at "2026-03-08T06:00:00Z"
                  :s3_key "_agent/summaries/2026-03-08.md"
                  :doc_count 5}]
      (is (.startsWith (:PK record) "insight#"))
      (is (.startsWith (:SK record) "summary#"))
      (is (= "daily_summary" (:type record)))
      (is (some? (:modified_at record)))
      (is (some? (:s3_key record)))))

  (testing "Weekly report insight record has required fields"
    (let [record {:PK "insight#test-user-sub"
                  :SK "report#2026-W10"
                  :type "weekly_report"
                  :title "Weekly Report: 2026-W10"
                  :modified_at "2026-03-03T06:00:00Z"
                  :s3_key "_agent/reports/weekly/2026-W10.md"
                  :doc_count 42}]
      (is (.startsWith (:PK record) "insight#"))
      (is (.startsWith (:SK record) "report#"))
      (is (= "weekly_report" (:type record)))))

  (testing "Search update insight record has required fields"
    (let [record {:PK "insight#test-user-sub"
                  :SK "search#abc123#2026-03-08T12:00:00Z"
                  :type "search_monitor"
                  :monitor_id "abc123"
                  :monitor_name "AI Safety Research"
                  :novelty_score 0.72
                  :modified_at "2026-03-08T12:00:00Z"
                  :s3_key "_agent/searches/abc123/2026-03-08.md"}]
      (is (.startsWith (:PK record) "insight#"))
      (is (.startsWith (:SK record) "search#"))
      (is (= "search_monitor" (:type record)))
      (is (some? (:monitor_id record))))))
