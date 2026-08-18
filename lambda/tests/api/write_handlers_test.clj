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

  (testing "Extracts groups from bracket-wrapped string (API Gateway v2 format)"
    (let [event {:requestContext {:authorizer {:jwt {:claims {(keyword "cognito:groups") "[admin]"}}}}}]
      (is (contains? (r/get-user-groups event) "admin"))))

  (testing "Extracts multiple groups from bracket-wrapped string"
    (let [event {:requestContext {:authorizer {:jwt {:claims {(keyword "cognito:groups") "[admin reader]"}}}}}]
      (is (contains? (r/get-user-groups event) "admin"))
      (is (contains? (r/get-user-groups event) "reader"))))

  (testing "Extracts groups from comma-separated bracket-wrapped string"
    (let [event {:requestContext {:authorizer {:jwt {:claims {(keyword "cognito:groups") "[admin, reader]"}}}}}]
      (is (contains? (r/get-user-groups event) "admin"))
      (is (contains? (r/get-user-groups event) "reader"))))

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

(defn conflict?
  "Return true when an update should be rejected due to a modification
   conflict. Mirrors the api_update_document handler logic:
   ifUnmodifiedSince is optional; when present, reject if current
   modified timestamp is after the condition."
  [current-modified if-unmodified-since]
  (boolean
    (when if-unmodified-since
      (pos? (compare current-modified if-unmodified-since)))))

(deftest conflict-detection-test
  (testing "No conflict when ifUnmodifiedSince matches"
    (is (false? (conflict? "2025-01-15T10:00:00Z" "2025-01-15T10:00:00Z"))))

  (testing "Conflict when document was modified after client fetch"
    (is (true? (conflict? "2025-01-15T12:00:00Z" "2025-01-15T10:00:00Z"))))

  (testing "No conflict when ifUnmodifiedSince is nil (skip check)"
    (is (false? (conflict? "2025-01-15T12:00:00Z" nil))))

  (testing "No conflict when current is before ifUnmodifiedSince"
    (is (false? (conflict? "2025-01-15T08:00:00Z" "2025-01-15T10:00:00Z")))))

;; =============================================================================
;; api_update_document key validation tests
;; =============================================================================

(defn validate-update-key
  "Validate the document key for api_update_document."
  [key]
  (cond
    (str/blank? key)
    "Document key is required"

    (str/starts-with? key "_agent/")
    "Cannot update agent-generated documents"

    (str/starts-with? key "_")
    "Document key must not start with _"

    (str/starts-with? key ".")
    "Document key must not start with ."

    (re-find #"\.\." key)
    "Document key must not contain .."

    :else nil))

(deftest validate-update-key-test
  (testing "Allows normal document updates"
    (is (nil? (validate-update-key "notes/test.md")))
    (is (nil? (validate-update-key "daily/2025-01-15.md"))))

  (testing "Rejects agent-generated documents"
    (is (= "Cannot update agent-generated documents"
           (validate-update-key "_agent/summaries/2025-01-01.md")))
    (is (some? (validate-update-key "_agent/entities/person/alice.md"))))

  (testing "Rejects other underscore and dot prefixes"
    (is (some? (validate-update-key "_private/test.md")))
    (is (some? (validate-update-key ".obsidian/workspace.json"))))

  (testing "Rejects path traversal"
    (is (some? (validate-update-key "notes/../_agent/summaries/x.md"))))

  ;; The handler relies on this instead of a separate nil check, so a missing
  ;; path param must not slip through as valid.
  (testing "Rejects blank or missing key"
    (is (some? (validate-update-key "")))
    (is (some? (validate-update-key "   ")))
    (is (some? (validate-update-key nil)))))

;; =============================================================================
;; api_delete_document validation tests
;; =============================================================================

(defn validate-delete-key
  "Validate the document key for api_delete_document."
  [key]
  (cond
    (str/blank? key)
    "Document key is required"

    (str/starts-with? key "_agent/")
    "Deletion of agent documents is not allowed"

    :else nil))

(deftest delete-validation-test
  (testing "Rejects agent directory deletions"
    (is (= "Deletion of agent documents is not allowed"
           (validate-delete-key "_agent/summaries/2025-01-01.md"))))

  (testing "Allows normal document deletions"
    (is (nil? (validate-delete-key "notes/test.md"))))

  (testing "Rejects blank key"
    (is (some? (validate-delete-key "")))))
