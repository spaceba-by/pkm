(ns command.context-test
  "Unit tests for PKM context builder.
   Tests keyword extraction and context formatting logic
   without requiring actual AWS service connections."
  (:require [clojure.test :refer [deftest testing is]]
            [clojure.string :as str]
            [command.context :as ctx]))

;; =============================================================================
;; Keyword Extraction
;; =============================================================================

(deftest extract-keywords-test
  (testing "Extracts meaningful keywords from command text"
    (let [keywords (ctx/extract-keywords "summarize my meetings about architecture")]
      (is (contains? (set keywords) "meetings"))
      (is (contains? (set keywords) "architecture"))))

  (testing "Filters out stop words"
    (let [keywords (ctx/extract-keywords "find the documents about this")]
      (is (not (some #{"the" "about" "this" "find"} keywords)))))

  (testing "Filters out short words"
    (let [keywords (ctx/extract-keywords "a go to do it")]
      (is (empty? keywords))))

  (testing "Lowercases keywords"
    (let [keywords (ctx/extract-keywords "Find Project Alpha")]
      (is (every? #(= % (str/lower-case %)) keywords)))))

;; =============================================================================
;; Context Formatting
;; =============================================================================

(deftest format-context-test
  (testing "Formats recent documents section"
    (let [ctx (ctx/format-context {:recent-docs [{:title "Meeting Notes"
                                              :classification "meeting"
                                              :tags ["work"]
                                              :modified "2026-03-14"}]
                               :relevant-docs []
                               :summaries []})]
      (is (str/includes? ctx "Recent Documents"))
      (is (str/includes? ctx "Meeting Notes"))
      (is (str/includes? ctx "[meeting]"))
      (is (str/includes? ctx "work"))))

  (testing "Formats relevant document content"
    (let [ctx (ctx/format-context {:recent-docs []
                               :relevant-docs [{:path "notes/test.md"
                                                :content "Some content here"}]
                               :summaries []})]
      (is (str/includes? ctx "Relevant Document Content"))
      (is (str/includes? ctx "notes/test.md"))
      (is (str/includes? ctx "Some content here"))))

  (testing "Formats summaries"
    (let [ctx (ctx/format-context {:recent-docs []
                               :relevant-docs []
                               :summaries [{:date "2026-03-14"
                                            :content "Daily summary content"}]})]
      (is (str/includes? ctx "Daily Summaries"))
      (is (str/includes? ctx "2026-03-14"))
      (is (str/includes? ctx "Daily summary content"))))

  (testing "Returns fallback message when no context available"
    (let [ctx (ctx/format-context {:recent-docs []
                               :relevant-docs []
                               :summaries []})]
      (is (str/includes? ctx "No relevant context found"))))

  (testing "Combines all sections when all data present"
    (let [ctx (ctx/format-context {:recent-docs [{:title "Doc1" :classification "idea"}]
                               :relevant-docs [{:path "p.md" :content "c"}]
                               :summaries [{:date "2026-03-14" :content "s"}]})]
      (is (str/includes? ctx "Recent Documents"))
      (is (str/includes? ctx "Relevant Document Content"))
      (is (str/includes? ctx "Daily Summaries")))))
