(ns persistent-search.summarizer-test
  "Unit tests for search summarizer utility functions"
  (:require [clojure.test :refer [deftest is testing]]
            [search.summarizer :as summarizer]
            [clojure.string :as str]))

;; =============================================================================
;; format-search-report tests
;; =============================================================================

(deftest format-search-report-test
  (testing "Generates a valid markdown report with all sections"
    (let [report (summarizer/format-search-report
                  "AI News"
                  "Summary of AI developments"
                  ["artificial intelligence" "machine learning"]
                  {:novelty_score 0.7
                   :new_items ["New GPT model released" "OpenAI partnership"]
                   :changed_items ["Updated pricing"]
                   :removed_items ["Old model deprecated"]
                   :analysis "Significant updates in AI landscape"}
                  "2026-02-17T12:00:00Z")]

      ;; Check frontmatter
      (is (str/starts-with? report "---"))
      (is (str/includes? report "monitor: AI News"))
      (is (str/includes? report "date: 2026-02-17T12:00:00Z"))
      (is (str/includes? report "novelty_score: 0.7"))

      ;; Check main sections
      (is (str/includes? report "# Search Monitor: AI News"))
      (is (str/includes? report "**Novelty Score:** 0.70"))
      (is (str/includes? report "## Summary"))
      (is (str/includes? report "Summary of AI developments"))

      ;; Check diff sections
      (is (str/includes? report "## What's New"))
      (is (str/includes? report "Significant updates in AI landscape"))
      (is (str/includes? report "### New Findings"))
      (is (str/includes? report "- New GPT model released"))
      (is (str/includes? report "- OpenAI partnership"))
      (is (str/includes? report "### Changes"))
      (is (str/includes? report "- Updated pricing"))
      (is (str/includes? report "### No Longer Appearing"))
      (is (str/includes? report "- Old model deprecated"))))

  (testing "Handles empty diff gracefully"
    (let [report (summarizer/format-search-report
                  "Test Monitor"
                  "Test summary"
                  []
                  {:novelty_score 0.0
                   :new_items []
                   :changed_items []
                   :removed_items []
                   :analysis ""}
                  "2026-02-17T12:00:00Z")]

      (is (str/includes? report "# Search Monitor: Test Monitor"))
      (is (str/includes? report "**Novelty Score:** 0.00"))
      (is (str/includes? report "Test summary"))
      ;; Should not have diff subsections when lists are empty
      (is (not (str/includes? report "### New Findings")))
      (is (not (str/includes? report "### Changes")))
      (is (not (str/includes? report "### No Longer Appearing"))))))

;; =============================================================================
;; format-search-results-for-prompt tests (testing via summarizer namespace)
;; We test the public functions only; the formatting function is private.
;; =============================================================================

(deftest format-report-frontmatter-test
  (testing "Frontmatter contains required fields"
    (let [report (summarizer/format-search-report
                  "My Monitor"
                  "Some summary"
                  ["topic1" "topic2"]
                  {:novelty_score 0.5
                   :new_items []
                   :changed_items []
                   :removed_items []
                   :analysis ""}
                  "2026-01-01T00:00:00Z")
          lines (str/split-lines report)]

      ;; First line is ---
      (is (= "---" (first lines)))
      ;; Has topics
      (is (str/includes? report "topics: [topic1, topic2]"))
      ;; Has monitor name
      (is (str/includes? report "monitor: My Monitor"))
      ;; Has date
      (is (str/includes? report "date: 2026-01-01T00:00:00Z")))))
