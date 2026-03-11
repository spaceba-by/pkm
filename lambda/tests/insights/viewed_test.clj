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

;; =============================================================================
;; Merge logic tests (DynamoDB + S3 listing)
;; These test the merge strategy used by api_list_summaries and api_list_reports
;; to ensure pre-migration S3-only entries are included alongside DynamoDB records.
;; =============================================================================

(defn- merge-summaries
  "Replicate the merge logic from handler/list-daily-summaries (api_list_summaries)"
  [ddb-results s3-results limit]
  (let [ddb-dates (set (map :date ddb-results))
        s3-only (remove #(contains? ddb-dates (:date %)) s3-results)]
    (->> (concat ddb-results s3-only)
         (sort-by :date #(compare %2 %1))
         (take limit)
         (vec))))

(defn- merge-reports
  "Replicate the merge logic from handler/list-reports (api_list_reports)"
  [ddb-results s3-results limit]
  (let [ddb-weeks (set (map :weekOf ddb-results))
        s3-only (remove #(contains? ddb-weeks (:weekOf %)) s3-results)]
    (->> (concat ddb-results s3-only)
         (sort-by :weekOf #(compare %2 %1))
         (take limit)
         (vec))))

(deftest merge-summaries-s3-only-test
  (testing "When no DynamoDB records exist, all S3 results are returned as viewed"
    (let [s3 [{:id "_agent/summaries/2026-03-08.md" :date "2026-03-08" :viewed true}
              {:id "_agent/summaries/2026-03-07.md" :date "2026-03-07" :viewed true}]
          result (merge-summaries [] s3 100)]
      (is (= 2 (count result)))
      (is (every? :viewed result)))))

(deftest merge-summaries-ddb-only-test
  (testing "When all summaries have DynamoDB records, S3 duplicates are excluded"
    (let [ddb [{:id "_agent/summaries/2026-03-08.md" :date "2026-03-08" :viewed false}
               {:id "_agent/summaries/2026-03-07.md" :date "2026-03-07" :viewed true}]
          s3 [{:id "_agent/summaries/2026-03-08.md" :date "2026-03-08" :viewed true}
              {:id "_agent/summaries/2026-03-07.md" :date "2026-03-07" :viewed true}]
          result (merge-summaries ddb s3 100)]
      (is (= 2 (count result)))
      ;; DynamoDB viewed status takes precedence
      (is (not (:viewed (first result))))
      (is (:viewed (second result))))))

(deftest merge-summaries-mixed-test
  (testing "Pre-migration S3 summaries are included alongside newer DynamoDB records"
    (let [;; Recent summaries with DynamoDB insight records
          ddb [{:id "_agent/summaries/2026-03-08.md" :date "2026-03-08" :viewed false}
               {:id "_agent/summaries/2026-03-07.md" :date "2026-03-07" :viewed true}]
          ;; S3 has both recent and older summaries
          s3 [{:id "_agent/summaries/2026-03-08.md" :date "2026-03-08" :viewed true}
              {:id "_agent/summaries/2026-03-07.md" :date "2026-03-07" :viewed true}
              {:id "_agent/summaries/2026-03-01.md" :date "2026-03-01" :viewed true}
              {:id "_agent/summaries/2026-02-28.md" :date "2026-02-28" :viewed true}]
          result (merge-summaries ddb s3 100)]
      ;; All 4 summaries should be present
      (is (= 4 (count result)))
      ;; Sorted newest first
      (is (= ["2026-03-08" "2026-03-07" "2026-03-01" "2026-02-28"]
             (map :date result)))
      ;; DynamoDB viewed status for recent, S3 defaults for older
      (is (not (:viewed (first result))))
      (is (:viewed (second result)))
      (is (:viewed (nth result 2)))
      (is (:viewed (nth result 3))))))

(deftest merge-summaries-respects-limit-test
  (testing "Merged results are limited correctly"
    (let [ddb [{:id "s1" :date "2026-03-08" :viewed false}]
          s3 [{:id "s1" :date "2026-03-08" :viewed true}
              {:id "s2" :date "2026-03-07" :viewed true}
              {:id "s3" :date "2026-03-06" :viewed true}]
          result (merge-summaries ddb s3 2)]
      (is (= 2 (count result)))
      (is (= ["2026-03-08" "2026-03-07"] (map :date result))))))

(deftest merge-reports-mixed-test
  (testing "Pre-migration S3 reports are included alongside newer DynamoDB records"
    (let [ddb [{:id "r1" :weekOf "2026-W10" :viewed false}]
          s3 [{:id "r1" :weekOf "2026-W10" :viewed true}
              {:id "r2" :weekOf "2026-W09" :viewed true}
              {:id "r3" :weekOf "2026-W08" :viewed true}]
          result (merge-reports ddb s3 100)]
      (is (= 3 (count result)))
      (is (= ["2026-W10" "2026-W09" "2026-W08"] (map :weekOf result)))
      ;; DynamoDB viewed status for W10, S3 defaults for older
      (is (not (:viewed (first result))))
      (is (:viewed (second result)))
      (is (:viewed (nth result 2))))))
