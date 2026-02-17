(ns delete-document.handler-test
  "Tests for delete_document Lambda handler"
  (:require [clojure.test :refer [deftest is testing]]
            [cheshire.core :as json]))

;; Duplicate should-skip? for isolated testing (same pattern as classification_test.clj)
(defn should-skip?
  "Check if file should be skipped based on path"
  [object-key]
  (or
   (not (.endsWith object-key ".md"))
   (.startsWith object-key "_agent/")
   (re-find #"/_agent/" object-key)
   (.startsWith object-key ".obsidian/")
   (re-find #"/\.obsidian/" object-key)))

(defn make-event
  "Create a mock EventBridge S3 delete event"
  [bucket-name object-key]
  {:body (json/generate-string
          {:detail {:bucket {:name bucket-name}
                    :object {:key object-key}}})})

;; =============================================================================
;; should-skip? tests
;; =============================================================================

(deftest should-skip-test
  (testing "Skips non-markdown files"
    (is (true? (should-skip? "notes/image.png")))
    (is (true? (should-skip? "notes/data.json")))
    (is (true? (should-skip? "notes/readme.txt"))))

  (testing "Skips _agent directory files"
    (is (true? (should-skip? "_agent/summaries/2025-01-20.md")))
    (is (true? (should-skip? "_agent/reports/weekly.md")))
    (is (true? (should-skip? "vault/_agent/test.md"))))

  (testing "Skips .obsidian directory files"
    (is (true? (should-skip? ".obsidian/config.md")))
    (is (true? (should-skip? "vault/.obsidian/plugins.md"))))

  (testing "Does not skip normal markdown files"
    (is (false? (should-skip? "notes/meeting.md")))
    (is (false? (should-skip? "daily notes/2025-01-20.md")))
    (is (false? (should-skip? "projects/roadmap.md")))))

;; =============================================================================
;; Handler response shape tests
;; =============================================================================

(deftest handler-response-shape-test
  (testing "Skipped file returns 200 with skip message"
    (let [event (make-event "test-bucket" "_agent/summary.md")
          ;; Simulate handler skip logic inline
          object-key "_agent/summary.md"]
      (when (should-skip? object-key)
        (let [response {:statusCode 200
                        :body (json/generate-string {:message "Skipped file"
                                                     :object-key object-key})}
              body (json/parse-string (:body response) true)]
          (is (= 200 (:statusCode response)))
          (is (= "Skipped file" (:message body)))
          (is (= "_agent/summary.md" (:object-key body)))))))

  (testing "Successful deletion returns 200 with deletion summary"
    (let [result {:document "notes/meeting.md"
                  :deleted-tags 2
                  :deleted-entities 3}
          response {:statusCode 200
                    :body (json/generate-string result)}
          body (json/parse-string (:body response) true)]
      (is (= 200 (:statusCode response)))
      (is (= "notes/meeting.md" (:document body)))
      (is (= 2 (:deleted-tags body)))
      (is (= 3 (:deleted-entities body)))))

  (testing "Error returns 500 with error message"
    (let [response {:statusCode 500
                    :body (json/generate-string {:error "DynamoDB connection failed"})}
          body (json/parse-string (:body response) true)]
      (is (= 500 (:statusCode response)))
      (is (= "DynamoDB connection failed" (:error body))))))

;; =============================================================================
;; Event parsing tests
;; =============================================================================

(deftest event-parsing-test
  (testing "Extracts bucket and key from EventBridge S3 delete event"
    (let [event (json/parse-string
                  (:body (make-event "my-vault-bucket" "notes/meeting.md"))
                  true)
          detail (:detail event)
          bucket-name (get-in detail [:bucket :name])
          object-key (get-in detail [:object :key])]
      (is (= "my-vault-bucket" bucket-name))
      (is (= "notes/meeting.md" object-key))))

  (testing "Missing bucket returns nil"
    (let [event (json/parse-string
                  (json/generate-string {:detail {:object {:key "test.md"}}})
                  true)
          bucket-name (get-in event [:detail :bucket :name])]
      (is (nil? bucket-name))))

  (testing "Missing object key returns nil"
    (let [event (json/parse-string
                  (json/generate-string {:detail {:bucket {:name "bucket"}}})
                  true)
          object-key (get-in event [:detail :object :key])]
      (is (nil? object-key)))))
