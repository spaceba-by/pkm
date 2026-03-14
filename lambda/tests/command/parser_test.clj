(ns command.parser-test
  "Unit tests for @sal command parser"
  (:require [clojure.test :refer [deftest testing is]]
            [command.parser :as parser]))

;; =============================================================================
;; parse-commands
;; =============================================================================

(deftest parse-commands-basic-test
  (testing "Parses a single @sal command"
    (let [content "Some text\n@sal summarize my meetings this week\nMore text"
          result (parser/parse-commands content)]
      (is (= 1 (count result)))
      (is (= "summarize my meetings this week" (:command (first result))))))

  (testing "Parses multiple @sal commands"
    (let [content "@sal find documents about architecture\nSome text\n@sal what meetings happened yesterday"
          result (parser/parse-commands content)]
      (is (= 2 (count result)))
      (is (= "find documents about architecture" (:command (first result))))
      (is (= "what meetings happened yesterday" (:command (second result))))))

  (testing "Returns line numbers"
    (let [content "Line 1\n@sal do something\nLine 3\n@sal do another thing"
          result (parser/parse-commands content)]
      (is (= 2 (:line-number (first result))))
      (is (= 4 (:line-number (second result)))))))

(deftest parse-commands-code-blocks-test
  (testing "Ignores @sal inside fenced code blocks"
    (let [content "Normal text\n```\n@sal this should be ignored\n```\n@sal this should be found"
          result (parser/parse-commands content)]
      (is (= 1 (count result)))
      (is (= "this should be found" (:command (first result))))))

  (testing "Ignores @sal inside language-tagged code blocks"
    (let [content "```clojure\n@sal ignored\n```\n@sal found"
          result (parser/parse-commands content)]
      (is (= 1 (count result)))
      (is (= "found" (:command (first result)))))))

(deftest parse-commands-edge-cases-test
  (testing "Returns nil for content without @sal"
    (is (nil? (parser/parse-commands "No commands here"))))

  (testing "Returns nil for nil content"
    (is (nil? (parser/parse-commands nil))))

  (testing "Returns empty for @sal with no command text"
    (let [result (parser/parse-commands "@sal")]
      (is (or (nil? result) (empty? result)))))

  (testing "Handles @sal with extra whitespace"
    (let [result (parser/parse-commands "  @sal  do something  ")]
      (is (= 1 (count result)))
      (is (= "do something" (:command (first result)))))))

;; =============================================================================
;; has-commands?
;; =============================================================================

(deftest has-commands-test
  (testing "Returns true when commands exist"
    (is (true? (parser/has-commands? "@sal find stuff"))))

  (testing "Returns false when no commands"
    (is (false? (parser/has-commands? "No commands here"))))

  (testing "Returns false for nil"
    (is (false? (parser/has-commands? nil))))

  (testing "Returns false when @sal only in code blocks"
    (is (false? (parser/has-commands? "```\n@sal ignored\n```")))))
