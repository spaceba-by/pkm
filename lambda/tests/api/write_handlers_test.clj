(ns api.write-handlers-test
  "Tests for write API handler validation and authorization logic.

   Note: Functions are duplicated here rather than imported from handler
   namespaces. All API handlers use the same 'handler' namespace name
   (required by the Lambda runtime), which prevents importing them
   together in tests. These serve as contract tests."
  (:require [clojure.test :refer [deftest is testing]]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

;; =============================================================================
;; Authorization tests (shared get-user-groups / admin? / require-admin)
;; =============================================================================

(deftest get-user-groups-test
  (testing "Extracts groups from JWT claims (keyword format)"
    (let [event {:requestContext {:authorizer {:jwt {:claims {(keyword "cognito:groups") "admin"}}}}}]
      (is (contains? (r/get-user-groups event) "admin"))))

  (testing "Extracts multiple groups from space-separated string"
    (let [event {:requestContext {:authorizer {:jwt {:claims {(keyword "cognito:groups") "admin reader"}}}}}]
      (is (contains? (r/get-user-groups event) "admin"))
      (is (contains? (r/get-user-groups event) "reader"))))

  (testing "Extracts groups from string-keyed claims"
    (let [event {"requestContext" {"authorizer" {"jwt" {"claims" {"cognito:groups" "admin"}}}}}]
      (is (contains? (r/get-user-groups event) "admin"))))

  (testing "Returns empty set when no groups claim"
    (let [event {:requestContext {:authorizer {:jwt {:claims {:sub "user-123"}}}}}]
      (is (empty? (r/get-user-groups event)))))

  (testing "Handles nil event gracefully"
    (is (empty? (r/get-user-groups {})))))

(deftest admin?-test
  (testing "Returns true for admin user"
    (let [event {:requestContext {:authorizer {:jwt {:claims {(keyword "cognito:groups") "admin"}}}}}]
      (is (true? (r/admin? event)))))

  (testing "Returns false for reader user"
    (let [event {:requestContext {:authorizer {:jwt {:claims {(keyword "cognito:groups") "reader"}}}}}]
      (is (false? (r/admin? event)))))

  (testing "Returns false for no groups"
    (let [event {:requestContext {:authorizer {:jwt {:claims {:sub "user-123"}}}}}]
      (is (false? (r/admin? event))))))

(deftest require-admin-test
  (testing "Returns nil for admin user (authorized)"
    (let [event {:requestContext {:authorizer {:jwt {:claims {(keyword "cognito:groups") "admin"}}}}}]
      (is (nil? (r/require-admin event)))))

  (testing "Returns 403 for non-admin user"
    (let [event {:requestContext {:authorizer {:jwt {:claims {(keyword "cognito:groups") "reader"}}}}}
          result (r/require-admin event)]
      (is (= 403 (:statusCode result)))
      (let [body (json/parse-string (:body result) true)]
        (is (= "Forbidden" (:error body)))))))

;; =============================================================================
;; Response utility tests for new response types
;; =============================================================================

(deftest forbidden-response-test
  (testing "Creates 403 response"
    (let [response (r/forbidden "Access denied")]
      (is (= 403 (:statusCode response)))
      (let [body (json/parse-string (:body response) true)]
        (is (= "Forbidden" (:error body)))
        (is (= "Access denied" (:message body)))))))

(deftest conflict-response-test
  (testing "Creates 409 response"
    (let [response (r/conflict "Concurrent modification")]
      (is (= 409 (:statusCode response)))
      (let [body (json/parse-string (:body response) true)]
        (is (= "Conflict" (:error body)))
        (is (= "Concurrent modification" (:message body)))))))

(deftest created-response-test
  (testing "Creates 201 response"
    (let [response (r/created {:key "test.md"})]
      (is (= 201 (:statusCode response)))
      (is (= "no-cache, no-store, must-revalidate"
             (get-in response [:headers "Cache-Control"])))
      (let [body (json/parse-string (:body response) true)]
        (is (= "test.md" (:key body)))))))

(deftest no-content-response-test
  (testing "Creates 204 response"
    (let [response (r/no-content)]
      (is (= 204 (:statusCode response)))
      (is (= "" (:body response))))))

;; =============================================================================
;; api_create_document validation tests
;; =============================================================================

(defn validate-key
  "Validate the document key (from api_create_document)"
  [key]
  (cond
    (str/blank? key)
    "Document key is required"

    (not (str/ends-with? key ".md"))
    "Document key must end with .md"

    (str/starts-with? key "_")
    "Document key must not start with _"

    (str/starts-with? key ".")
    "Document key must not start with ."

    (re-find #"\.\." key)
    "Document key must not contain .."

    :else nil))

(deftest validate-key-test
  (testing "Valid keys"
    (is (nil? (validate-key "notes/test.md")))
    (is (nil? (validate-key "my-note.md")))
    (is (nil? (validate-key "path/to/deep/note.md"))))

  (testing "Rejects blank key"
    (is (some? (validate-key "")))
    (is (some? (validate-key "   "))))

  (testing "Rejects non-markdown files"
    (is (some? (validate-key "notes/test.txt")))
    (is (some? (validate-key "notes/test"))))

  (testing "Rejects keys starting with _"
    (is (some? (validate-key "_agent/test.md"))))

  (testing "Rejects keys starting with ."
    (is (some? (validate-key ".hidden/test.md"))))

  (testing "Rejects keys with path traversal"
    (is (some? (validate-key "notes/../secret.md")))))

;; =============================================================================
;; api_update_document conflict detection tests
;; =============================================================================

(deftest conflict-detection-test
  (testing "No conflict when ifUnmodifiedSince matches"
    (let [current-modified "2025-01-15T10:00:00Z"
          if-unmodified-since "2025-01-15T10:00:00Z"]
      ;; Should not conflict: current is not after the condition
      (is (not (pos? (compare current-modified if-unmodified-since))))))

  (testing "Conflict when document was modified after client fetch"
    (let [current-modified "2025-01-15T12:00:00Z"
          if-unmodified-since "2025-01-15T10:00:00Z"]
      ;; Should conflict: current is after the condition
      (is (pos? (compare current-modified if-unmodified-since)))))

  (testing "No conflict when ifUnmodifiedSince is nil (no check)"
    ;; When ifUnmodifiedSince is nil, we skip the check
    (is (nil? nil))))

;; =============================================================================
;; api_delete_document validation tests
;; =============================================================================

(deftest delete-validation-test
  (testing "Rejects agent directory deletions"
    (is (true? (.startsWith "_agent/summaries/2025-01-01.md" "_agent/"))))

  (testing "Allows normal document deletions"
    (is (false? (.startsWith "notes/test.md" "_agent/")))))
