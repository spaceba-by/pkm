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

  (testing "Line numbers after a code block are preserved"
    (let [content "```\ncode\nmore\n```\n@sal after block"
          result (parser/parse-commands content)]
      (is (= 5 (:line-number (first result))))))

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

;; =============================================================================
;; parse-workflow-commands
;; =============================================================================

(deftest parse-workflow-commands-test
  (testing "Parses name and args"
    (let [result (parser/parse-workflow-commands "Intro\n@workflow:research quantum error correction\nMore")]
      (is (= 1 (count result)))
      (is (= "research" (:name (first result))))
      (is (= "quantum error correction" (:args (first result))))
      (is (= 2 (:line-number (first result))))))

  (testing "Args are optional and default to empty string"
    (let [result (parser/parse-workflow-commands "@workflow:digest")]
      (is (= [{:name "digest" :args "" :line-number 1}] result))))

  (testing "Name is lower-cased; hyphenated names allowed"
    (let [result (parser/parse-workflow-commands "@workflow:Action-Items please")]
      (is (= "action-items" (:name (first result))))
      (is (= "please" (:args (first result))))))

  (testing "Multiple commands keep order and line numbers"
    (let [result (parser/parse-workflow-commands "@workflow:a\ntext\n@workflow:b with args")]
      (is (= ["a" "b"] (map :name result)))
      (is (= [1 3] (map :line-number result)))))

  (testing "Ignores commands inside fenced code blocks"
    (let [result (parser/parse-workflow-commands "```\n@workflow:ignored\n```\n@workflow:found")]
      (is (= ["found"] (map :name result)))
      (is (= 4 (:line-number (first result))))))

  (testing "Does not match inline mentions or @sal commands"
    (is (empty? (parser/parse-workflow-commands "see @workflow:research for details")))
    (is (empty? (parser/parse-workflow-commands "@sal summarize this")))
    (is (empty? (parser/parse-workflow-commands "@workflow: missing-name")))
    (is (empty? (parser/parse-workflow-commands "@workflow:-bad")))
    (is (empty? (parser/parse-workflow-commands "@Workflow:upper-marker"))))

  (testing "Returns nil without a marker or for nil content"
    (is (nil? (parser/parse-workflow-commands "nothing here")))
    (is (nil? (parser/parse-workflow-commands nil))))

  (testing "@sal parsing is unaffected by @workflow lines"
    (is (= 1 (count (parser/parse-commands "@workflow:x\n@sal do it"))))))

(deftest has-workflow-commands-test
  (is (true? (parser/has-workflow-commands? "@workflow:x")))
  (is (false? (parser/has-workflow-commands? "```\n@workflow:x\n```")))
  (is (false? (parser/has-workflow-commands? nil))))
