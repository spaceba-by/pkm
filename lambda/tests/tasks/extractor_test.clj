(ns tasks.extractor-test
  "Tests for task extraction from markdown content"
  (:require [clojure.test :refer [deftest is testing]]
            [tasks.extractor :as extractor]))

;; =============================================================================
;; Task ID generation tests
;; =============================================================================

(deftest generate-task-id-test
  (testing "Generates deterministic IDs"
    (let [id1 (extractor/generate-task-id "notes/meeting.md" 5 "Review proposal")
          id2 (extractor/generate-task-id "notes/meeting.md" 5 "Review proposal")]
      (is (= id1 id2) "Same inputs should produce same ID")))

  (testing "Different inputs produce different IDs"
    (let [id1 (extractor/generate-task-id "notes/meeting.md" 5 "Review proposal")
          id2 (extractor/generate-task-id "notes/meeting.md" 6 "Review proposal")
          id3 (extractor/generate-task-id "notes/other.md" 5 "Review proposal")]
      (is (not= id1 id2) "Different line numbers should produce different IDs")
      (is (not= id1 id3) "Different paths should produce different IDs")))

  (testing "ID starts with t- prefix"
    (let [id (extractor/generate-task-id "test.md" 1 "Do something")]
      (is (clojure.string/starts-with? id "t-"))))

  (testing "Handles long descriptions by truncating to 80 chars"
    (let [long-desc (apply str (repeat 200 "a"))
          id1 (extractor/generate-task-id "test.md" 1 long-desc)
          id2 (extractor/generate-task-id "test.md" 1 (str long-desc "extra"))]
      (is (= id1 id2) "Descriptions longer than 80 chars should produce same ID"))))

;; =============================================================================
;; Checkbox extraction tests
;; =============================================================================

(deftest extract-checkbox-tasks-test
  (testing "Extracts open checkbox"
    (let [content "Some text\n- [ ] Review the proposal\nMore text"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= 1 (count tasks)))
      (is (= "Review the proposal" (:description (first tasks))))
      (is (= "open" (:status (first tasks))))
      (is (= "checkbox" (:marker (first tasks))))
      (is (= 2 (:line_number (first tasks))))))

  (testing "Extracts completed checkbox"
    (let [content "- [x] Done task"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= 1 (count tasks)))
      (is (= "completed" (:status (first tasks))))))

  (testing "Handles uppercase X"
    (let [content "- [X] Done task"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= 1 (count tasks)))
      (is (= "completed" (:status (first tasks))))))

  (testing "Extracts multiple checkboxes"
    (let [content "# Tasks\n- [ ] First task\n- [x] Second task\n- [ ] Third task"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= 3 (count tasks)))
      (is (= "open" (:status (first tasks))))
      (is (= "completed" (:status (second tasks))))
      (is (= "open" (:status (nth tasks 2))))))

  (testing "Handles indented checkboxes"
    (let [content "  - [ ] Indented task"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= 1 (count tasks)))
      (is (= "Indented task" (:description (first tasks))))))

  (testing "Handles asterisk bullet markers"
    (let [content "* [ ] Star task"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= 1 (count tasks)))
      (is (= "Star task" (:description (first tasks))))))

  (testing "Handles plus bullet markers"
    (let [content "+ [ ] Plus task"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= 1 (count tasks)))
      (is (= "Plus task" (:description (first tasks))))))

  (testing "Does not match non-checkbox lines"
    (let [content "- Regular bullet\n[not a checkbox]\n## Heading"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= 0 (count tasks)))))

  (testing "Preserves context as original line"
    (let [content "- [ ] Review by Friday"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= "- [ ] Review by Friday" (:context (first tasks))))))

  (testing "All tasks have source=pattern"
    (let [content "- [ ] Task one\n- [x] Task two"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (every? #(= "pattern" (:source %)) tasks)))))

;; =============================================================================
;; Due date extraction tests
;; =============================================================================

(deftest checkbox-due-date-test
  (testing "Extracts due date with 'by' keyword"
    (let [content "- [ ] Review proposal by 2026-03-20"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= "2026-03-20" (:due_date (first tasks))))))

  (testing "Extracts due date with 'due' keyword"
    (let [content "- [ ] Submit report due 2026-04-01"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= "2026-04-01" (:due_date (first tasks))))))

  (testing "Extracts due date with 'before' keyword"
    (let [content "- [ ] Complete work before 2026-05-15"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= "2026-05-15" (:due_date (first tasks))))))

  (testing "No due date when no date keyword present"
    (let [content "- [ ] Just a regular task"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (nil? (:due_date (first tasks)))))))

;; =============================================================================
;; Priority detection tests
;; =============================================================================

(deftest checkbox-priority-test
  (testing "Detects high priority with 'urgent'"
    (let [content "- [ ] Urgent: fix production bug"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= "high" (:priority (first tasks))))))

  (testing "Detects high priority with 'critical'"
    (let [content "- [ ] Critical security patch needed"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= "high" (:priority (first tasks))))))

  (testing "Detects medium priority with 'important'"
    (let [content "- [ ] Important: update documentation"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= "medium" (:priority (first tasks))))))

  (testing "Detects low priority with 'nice to have'"
    (let [content "- [ ] Nice to have: dark mode support"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (= "low" (:priority (first tasks))))))

  (testing "No priority for regular task"
    (let [content "- [ ] Review the code"
          tasks (extractor/extract-checkbox-tasks content)]
      (is (nil? (:priority (first tasks)))))))

;; =============================================================================
;; Marker extraction tests
;; =============================================================================

(deftest extract-marker-tasks-test
  (testing "Extracts TODO marker"
    (let [content "Some code\n// TODO: refactor this function\nMore code"
          tasks (extractor/extract-marker-tasks content)]
      (is (= 1 (count tasks)))
      (is (= "refactor this function" (:description (first tasks))))
      (is (= "todo" (:marker (first tasks))))
      (is (= 2 (:line_number (first tasks))))))

  (testing "Extracts TODO without colon"
    (let [content "TODO fix the build"
          tasks (extractor/extract-marker-tasks content)]
      (is (= 1 (count tasks)))
      (is (= "fix the build" (:description (first tasks))))))

  (testing "Extracts ACTION marker"
    (let [content "ACTION: schedule follow-up meeting"
          tasks (extractor/extract-marker-tasks content)]
      (is (= 1 (count tasks)))
      (is (= "schedule follow-up meeting" (:description (first tasks))))
      (is (= "action" (:marker (first tasks))))))

  (testing "Extracts FIXME marker"
    (let [content "FIXME: memory leak in parser"
          tasks (extractor/extract-marker-tasks content)]
      (is (= 1 (count tasks)))
      (is (= "memory leak in parser" (:description (first tasks))))
      (is (= "fixme" (:marker (first tasks))))))

  (testing "Case-insensitive matching"
    (let [content "todo: lowercase task\nTodo: mixed case task"
          tasks (extractor/extract-marker-tasks content)]
      (is (= 2 (count tasks)))))

  (testing "All marker tasks are open"
    (let [content "TODO: task one\nACTION: task two\nFIXME: task three"
          tasks (extractor/extract-marker-tasks content)]
      (is (every? #(= "open" (:status %)) tasks))))

  (testing "Does not double-extract checkboxes with TODO"
    (let [content "- [ ] TODO: this is a checkbox task"
          tasks (extractor/extract-marker-tasks content)]
      (is (= 0 (count tasks)) "Checkbox lines should be skipped by marker extraction")))

  (testing "All marker tasks have source=pattern"
    (let [content "TODO: task one\nACTION: task two"
          tasks (extractor/extract-marker-tasks content)]
      (is (every? #(= "pattern" (:source %)) tasks)))))

;; =============================================================================
;; Combined pattern extraction tests
;; =============================================================================

(deftest extract-pattern-tasks-test
  (testing "Combines checkboxes and markers"
    (let [content (str "# Meeting Notes\n"
                       "- [ ] Follow up with team\n"
                       "- [x] Send agenda\n"
                       "TODO: book conference room\n"
                       "ACTION: notify stakeholders")
          tasks (extractor/extract-pattern-tasks content)]
      (is (= 4 (count tasks)))
      (is (= 2 (count (filter #(= "checkbox" (:marker %)) tasks))))
      (is (= 1 (count (filter #(= "todo" (:marker %)) tasks))))
      (is (= 1 (count (filter #(= "action" (:marker %)) tasks))))))

  (testing "Empty content returns empty vector"
    (let [tasks (extractor/extract-pattern-tasks "")]
      (is (= [] tasks))))

  (testing "Content with no tasks returns empty vector"
    (let [tasks (extractor/extract-pattern-tasks "Just regular text\nNo tasks here")]
      (is (= [] tasks)))))

;; =============================================================================
;; Task merging tests
;; =============================================================================

(deftest merge-tasks-test
  (testing "Non-overlapping tasks are all included"
    (let [pattern-tasks [{:description "Pattern task" :line_number 1 :marker "checkbox"}]
          ai-tasks [{:description "AI task" :line_number 10 :marker "implicit"}]
          merged (extractor/merge-tasks pattern-tasks ai-tasks)]
      (is (= 2 (count merged)))))

  (testing "Overlapping AI task is deduplicated (same line)"
    (let [pattern-tasks [{:description "Review proposal" :line_number 5 :marker "checkbox"}]
          ai-tasks [{:description "Review the proposal" :line_number 5 :marker "implicit"}]
          merged (extractor/merge-tasks pattern-tasks ai-tasks)]
      (is (= 1 (count merged)))
      (is (= "checkbox" (:marker (first merged))))))

  (testing "Overlapping AI task deduplicated (close lines, similar description)"
    (let [pattern-tasks [{:description "fix the build" :line_number 10 :marker "todo"}]
          ai-tasks [{:description "Fix the build system" :line_number 11 :marker "implicit"}]
          merged (extractor/merge-tasks pattern-tasks ai-tasks)]
      (is (= 1 (count merged)))
      (is (= "todo" (:marker (first merged))))))

  (testing "Pattern tasks always take priority"
    (let [pattern-tasks [{:description "Task A" :line_number 1 :marker "checkbox"}
                         {:description "Task B" :line_number 5 :marker "todo"}]
          ai-tasks [{:description "Task C" :line_number 20 :marker "implicit"}]
          merged (extractor/merge-tasks pattern-tasks ai-tasks)]
      (is (= 3 (count merged)))
      (is (= "Task A" (:description (first merged))))
      (is (= "Task B" (:description (second merged))))
      (is (= "Task C" (:description (nth merged 2))))))

  (testing "Empty AI tasks returns only pattern tasks"
    (let [pattern-tasks [{:description "Task" :line_number 1 :marker "checkbox"}]
          merged (extractor/merge-tasks pattern-tasks [])]
      (is (= 1 (count merged)))))

  (testing "Empty pattern tasks returns only AI tasks"
    (let [ai-tasks [{:description "AI Task" :line_number 5 :marker "implicit"}]
          merged (extractor/merge-tasks [] ai-tasks)]
      (is (= 1 (count merged))))))

;; =============================================================================
;; Realistic document tests
;; =============================================================================

(deftest realistic-document-test
  (testing "Meeting notes with mixed task formats"
    (let [content (str "# Weekly Standup 2026-03-15\n"
                       "\n"
                       "## Attendees\n"
                       "- Alice, Bob, Charlie\n"
                       "\n"
                       "## Discussion\n"
                       "Discussed the Q2 roadmap.\n"
                       "\n"
                       "## Action Items\n"
                       "- [ ] Alice to prepare the budget proposal by 2026-03-20\n"
                       "- [ ] Bob to review API documentation\n"
                       "- [x] Charlie completed the design mockup\n"
                       "\n"
                       "TODO: schedule next planning session\n"
                       "FIXME: broken link in wiki\n")
          tasks (extractor/extract-pattern-tasks content)]
      (is (= 5 (count tasks)))
      ;; Check Alice's task has due date
      (let [alice-task (first (filter #(clojure.string/includes? (:description %) "Alice") tasks))]
        (is (= "2026-03-20" (:due_date alice-task)))
        (is (= "open" (:status alice-task))))
      ;; Check Charlie's task is completed
      (let [charlie-task (first (filter #(clojure.string/includes? (:description %) "Charlie") tasks))]
        (is (= "completed" (:status charlie-task))))
      ;; Check status counts
      (is (= 4 (count (filter #(= "open" (:status %)) tasks))))
      (is (= 1 (count (filter #(= "completed" (:status %)) tasks)))))))
