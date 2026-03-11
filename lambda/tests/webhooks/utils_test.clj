(ns webhooks.utils-test
  "Unit tests for webhook shared utilities.
   Tests HMAC signature verification, webhook classification,
   key generation, document generation, and API response formatting."
  (:require [clojure.test :refer [deftest testing is]]
            [clojure.string :as str]
            [webhooks.utils :as wu]))

;; =============================================================================
;; Key Generation
;; =============================================================================

(deftest source-pk-test
  (testing "Source partition key is constant"
    (is (= "webhook_source" (wu/source-pk)))))

(deftest source-sk-test
  (testing "Source sort key format"
    (is (= "source#abc-123" (wu/source-sk "abc-123")))
    (is (str/starts-with? (wu/source-sk "x") "source#"))))

(deftest event-pk-test
  (testing "Event partition key is constant"
    (is (= "webhook_event" (wu/event-pk)))))

(deftest event-sk-test
  (testing "Event sort key format"
    (let [sk (wu/event-sk "2026-02-25T12:00:00Z" "evt-uuid")]
      (is (str/starts-with? sk "event#"))
      (is (str/includes? sk "2026-02-25T12:00:00Z"))
      (is (str/ends-with? sk "evt-uuid"))))

  (testing "Event sort keys sort chronologically"
    (let [sk1 (wu/event-sk "2026-02-24T12:00:00Z" "id1")
          sk2 (wu/event-sk "2026-02-25T12:00:00Z" "id2")]
      (is (neg? (compare sk1 sk2))))))

;; =============================================================================
;; HMAC Signature Verification
;; =============================================================================

(deftest hmac-sha256-hex-test
  (testing "Produces 64-char lowercase hex digest"
    (let [result (wu/hmac-sha256-hex "secret" "payload")]
      (is (= 64 (count result)))
      (is (re-matches #"[0-9a-f]+" result))))

  (testing "Same input produces same output"
    (is (= (wu/hmac-sha256-hex "key" "data")
           (wu/hmac-sha256-hex "key" "data"))))

  (testing "Different secret produces different output"
    (is (not= (wu/hmac-sha256-hex "key1" "data")
              (wu/hmac-sha256-hex "key2" "data"))))

  (testing "Different body produces different output"
    (is (not= (wu/hmac-sha256-hex "key" "data1")
              (wu/hmac-sha256-hex "key" "data2")))))

(deftest constant-time-equals-test
  (testing "Equal strings return true"
    (is (true? (wu/constant-time-equals "abc" "abc"))))

  (testing "Different strings return false"
    (is (not (wu/constant-time-equals "abc" "def"))))

  (testing "Different lengths return false"
    (is (not (wu/constant-time-equals "ab" "abc"))))

  (testing "Nil inputs return false"
    (is (not (wu/constant-time-equals nil "abc")))
    (is (not (wu/constant-time-equals "abc" nil)))))

(deftest verify-github-signature-test
  (testing "Accepts valid sha256= prefix signature"
    (let [secret "test-secret"
          body "{\"action\":\"opened\"}"
          sig (str "sha256=" (wu/hmac-sha256-hex secret body))]
      (is (true? (wu/verify-github-signature secret body sig)))))

  (testing "Rejects tampered body"
    (let [secret "test-secret"
          body "{\"action\":\"opened\"}"
          sig (str "sha256=" (wu/hmac-sha256-hex secret body))]
      (is (not (wu/verify-github-signature secret "{\"action\":\"closed\"}" sig)))))

  (testing "Rejects wrong secret"
    (let [body "payload"
          sig (str "sha256=" (wu/hmac-sha256-hex "secret1" body))]
      (is (not (wu/verify-github-signature "secret2" body sig)))))

  (testing "Rejects missing sha256= prefix"
    (let [secret "test-secret"
          body "payload"
          sig (wu/hmac-sha256-hex secret body)]
      (is (not (wu/verify-github-signature secret body sig)))))

  (testing "Returns falsy on nil/blank inputs"
    (is (not (wu/verify-github-signature nil "body" "sha256=abc")))
    (is (not (wu/verify-github-signature "secret" nil "sha256=abc")))
    (is (not (wu/verify-github-signature "secret" "body" nil)))
    (is (not (wu/verify-github-signature "" "body" "sha256=abc")))
    (is (not (wu/verify-github-signature "secret" "" "sha256=abc")))))

(deftest verify-hmac-signature-test
  (testing "Accepts raw hex signature"
    (let [secret "test-secret"
          body "payload"
          sig (wu/hmac-sha256-hex secret body)]
      (is (true? (wu/verify-hmac-signature secret body sig)))))

  (testing "Accepts sha256= prefixed signature"
    (let [secret "test-secret"
          body "payload"
          sig (str "sha256=" (wu/hmac-sha256-hex secret body))]
      (is (true? (wu/verify-hmac-signature secret body sig)))))

  (testing "Rejects invalid signature"
    (is (not (wu/verify-hmac-signature "secret" "payload" "invalid-hex"))))

  (testing "Returns falsy on nil/blank inputs"
    (is (not (wu/verify-hmac-signature nil "body" "sig")))
    (is (not (wu/verify-hmac-signature "secret" "body" nil)))
    (is (not (wu/verify-hmac-signature "secret" "body" "")))))

;; =============================================================================
;; Webhook Classification
;; =============================================================================

(deftest classify-webhook-github-test
  (testing "GitHub push events route to document"
    (let [headers {"x-github-event" "push"}
          payload {:ref "refs/heads/main" :commits [{:message "fix bug"}]}
          result (wu/classify-webhook "github" headers payload)]
      (is (= :document (:route result)))
      (is (= "push" (:event-type result)))))

  (testing "GitHub release events route to document"
    (let [headers {"x-github-event" "release"}
          payload {:release {:tag_name "v1.0.0"}}
          result (wu/classify-webhook "github" headers payload)]
      (is (= :document (:route result)))
      (is (= "release" (:event-type result)))))

  (testing "GitHub issue events route to event store"
    (let [headers {"x-github-event" "issues"}
          payload {:action "opened" :issue {:title "Bug"}}
          result (wu/classify-webhook "github" headers payload)]
      (is (= :event (:route result)))
      (is (= "issues" (:event-type result)))))

  (testing "GitHub PR events route to event store"
    (let [headers {"x-github-event" "pull_request"}
          payload {:action "opened" :pull_request {:title "Feature"}}
          result (wu/classify-webhook "github" headers payload)]
      (is (= :event (:route result)))
      (is (= "pull_request" (:event-type result))))))

(deftest classify-webhook-email-test
  (testing "Email payloads route to document"
    (let [result (wu/classify-webhook "email" {} {:subject "Meeting notes" :body "..."})]
      (is (= :document (:route result)))
      (is (= "email" (:event-type result)))
      (is (= "Meeting notes" (:title result)))))

  (testing "Email without subject uses default"
    (let [result (wu/classify-webhook "email" {} {:body "content"})]
      (is (= "No subject" (:title result))))))

(deftest classify-webhook-custom-test
  (testing "Custom/unknown source types default to event route"
    (let [result (wu/classify-webhook "custom" {} {:data "value"})]
      (is (= :event (:route result)))
      (is (= "custom" (:event-type result)))))

  (testing "Unknown source type defaults to event"
    (let [result (wu/classify-webhook "unknown-type" {} {:data "value"})]
      (is (= :event (:route result))))))

;; =============================================================================
;; Document Generation
;; =============================================================================

(deftest generate-document-path-test
  (testing "Document path has correct format"
    (let [path (wu/generate-document-path "src-123" "evt-456" "2026-02-25T12:00:00Z")]
      (is (= "_agent/webhooks/src-123/2026-02-25/evt-456.md" path))))

  (testing "Handles short/missing timestamp"
    (let [path (wu/generate-document-path "src" "evt" "short")]
      (is (str/includes? path "unknown-date"))))

  (testing "Handles nil timestamp"
    (let [path (wu/generate-document-path "src" "evt" nil)]
      (is (str/includes? path "unknown-date")))))

(deftest generate-markdown-test
  (testing "Generates valid markdown with frontmatter"
    (let [md (wu/generate-markdown "github" "push" "evt-123"
                                    "2026-02-25T12:00:00Z"
                                    "Push to main"
                                    {:ref "refs/heads/main" :commits []})]
      (is (str/starts-with? md "---\n"))
      (is (str/includes? md "source: github"))
      (is (str/includes? md "event_type: push"))
      (is (str/includes? md "webhook_id: evt-123"))
      (is (str/includes? md "received_at: 2026-02-25T12:00:00Z"))
      (is (str/includes? md "# Push to main"))))

  (testing "GitHub push body includes repository and commits"
    (let [md (wu/generate-markdown "github" "push" "evt-123"
                                    "2026-02-25T12:00:00Z"
                                    "Push"
                                    {:repository {:full_name "user/repo"}
                                     :ref "refs/heads/main"
                                     :commits [{:message "fix bug"}]})]
      (is (str/includes? md "**Repository:** user/repo"))
      (is (str/includes? md "fix bug"))))

  (testing "Email body includes from/to"
    (let [md (wu/generate-markdown "email" "email" "evt-123"
                                    "2026-02-25T12:00:00Z"
                                    "Meeting notes"
                                    {:from "alice@example.com"
                                     :to "bob@example.com"
                                     :body "Notes here"})]
      (is (str/includes? md "**From:** alice@example.com"))
      (is (str/includes? md "Notes here"))))

  (testing "Generic body uses pr-str"
    (let [md (wu/generate-markdown "custom" "custom" "evt-123"
                                    "2026-02-25T12:00:00Z"
                                    "Custom webhook"
                                    {:key "value"})]
      (is (str/includes? md "```edn")))))

;; =============================================================================
;; API Response Formatting
;; =============================================================================

(deftest format-source-test
  (testing "Formats source record for API response"
    (let [source {:source_id "src-123"
                  :name "GitHub Repo"
                  :source_type "github"
                  :source_status "active"
                  :signing_secret_arn "arn:aws:secretsmanager:us-east-1:123:secret:key"
                  :created "2026-02-25T00:00:00Z"
                  :modified "2026-02-25T00:00:00Z"}
          result (wu/format-source source)]
      (is (= "src-123" (:id result)))
      (is (= "GitHub Repo" (:name result)))
      (is (= "github" (:sourceType result)))
      (is (= "active" (:status result)))
      (is (some? (:signingSecretArn result)))
      (is (some? (:created result)))
      (is (some? (:modified result))))))

(deftest format-event-test
  (testing "Formats event record for API response"
    (let [event {:event_id "evt-456"
                 :source_id "src-123"
                 :source_type "github"
                 :event_type "push"
                 :route "document"
                 :title "Push to main"
                 :event_status "received"
                 :document_path "_agent/webhooks/src-123/2026-02-25/evt-456.md"
                 :received_at "2026-02-25T12:00:00Z"}
          result (wu/format-event event)]
      (is (= "evt-456" (:id result)))
      (is (= "src-123" (:sourceId result)))
      (is (= "github" (:sourceType result)))
      (is (= "push" (:eventType result)))
      (is (= "document" (:route result)))
      (is (= "Push to main" (:title result)))
      (is (= "received" (:status result)))
      (is (str/starts-with? (:documentPath result) "_agent/webhooks/"))
      (is (= "2026-02-25T12:00:00Z" (:receivedAt result))))))
