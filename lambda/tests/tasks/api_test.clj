(ns tasks.api-test
  "Tests for task API response formatting"
  (:require [clojure.test :refer [deftest is testing]]
            [cheshire.core :as json])
  (:import [java.util Base64]))

;; =============================================================================
;; Cursor encode/decode tests (duplicated for testability)
;; =============================================================================

(defn encode-cursor [last-key]
  (when last-key
    (.encodeToString (Base64/getUrlEncoder)
                     (.getBytes (json/generate-string last-key) "UTF-8"))))

(defn decode-cursor [cursor]
  (when (and cursor (not (empty? cursor)))
    (try
      (let [decoded (String. (.decode (Base64/getUrlDecoder) cursor) "UTF-8")]
        (json/parse-string decoded true))
      (catch Exception _ nil))))

(deftest cursor-roundtrip-test
  (testing "Encode and decode cursor roundtrip"
    (let [key {:PK "task#open" :SK "doc#notes/meeting.md#t-12345678"}
          encoded (encode-cursor key)
          decoded (decode-cursor encoded)]
      (is (= key decoded))))

  (testing "nil cursor encodes to nil"
    (is (nil? (encode-cursor nil))))

  (testing "nil cursor decodes to nil"
    (is (nil? (decode-cursor nil))))

  (testing "empty cursor decodes to nil"
    (is (nil? (decode-cursor "")))))

;; =============================================================================
;; Task formatting tests (duplicated from handler for testability)
;; =============================================================================

(defn format-task [task]
  (cond-> {:taskId (or (:task_id task) "")
           :description (or (:description task) "")
           :status (or (:status task) (:task_status task) "open")
           :source (or (:source task) "pattern")
           :marker (or (:marker task) "checkbox")
           :documentPath (or (:document_path task) "")}
    (:line_number task) (assoc :lineNumber (:line_number task))
    (:due_date task) (assoc :dueDate (:due_date task))
    (:priority task) (assoc :priority (:priority task))
    (:context task) (assoc :context (:context task))))

(deftest format-task-test
  (testing "Formats complete task index entry"
    (let [task {:task_id "t-12345678"
                :description "Review proposal"
                :status "open"
                :source "pattern"
                :marker "checkbox"
                :document_path "notes/meeting.md"
                :line_number 5
                :due_date "2026-03-20"
                :priority "high"
                :context "- [ ] Review proposal by 2026-03-20"}
          formatted (format-task task)]
      (is (= "t-12345678" (:taskId formatted)))
      (is (= "Review proposal" (:description formatted)))
      (is (= "open" (:status formatted)))
      (is (= "pattern" (:source formatted)))
      (is (= "checkbox" (:marker formatted)))
      (is (= "notes/meeting.md" (:documentPath formatted)))
      (is (= 5 (:lineNumber formatted)))
      (is (= "2026-03-20" (:dueDate formatted)))
      (is (= "high" (:priority formatted)))))

  (testing "Handles minimal task (no optional fields)"
    (let [task {:task_id "t-00000001"
                :description "Do something"
                :status "open"
                :source "pattern"
                :marker "todo"
                :document_path "notes/todo.md"}
          formatted (format-task task)]
      (is (= "t-00000001" (:taskId formatted)))
      (is (= "Do something" (:description formatted)))
      (is (not (contains? formatted :lineNumber)))
      (is (not (contains? formatted :dueDate)))
      (is (not (contains? formatted :priority)))))

  (testing "Handles missing fields gracefully"
    (let [task {}
          formatted (format-task task)]
      (is (= "" (:taskId formatted)))
      (is (= "" (:description formatted)))
      (is (= "open" (:status formatted)))
      (is (= "pattern" (:source formatted)))))

  (testing "Prefers :status over :task_status"
    (let [task {:status "completed" :task_status "open"}
          formatted (format-task task)]
      (is (= "completed" (:status formatted)))))

  (testing "Falls back to :task_status when :status missing"
    (let [task {:task_status "completed"}
          formatted (format-task task)]
      (is (= "completed" (:status formatted))))))

;; =============================================================================
;; Status validation tests
;; =============================================================================

(def valid-statuses #{"open" "completed" "all"})

(deftest status-validation-test
  (testing "Valid statuses are accepted"
    (doseq [status ["open" "completed" "all"]]
      (is (contains? valid-statuses status)
          (str status " should be valid"))))

  (testing "Invalid statuses are rejected"
    (doseq [status ["pending" "done" "closed" ""]]
      (is (not (contains? valid-statuses status))
          (str status " should be rejected")))))
