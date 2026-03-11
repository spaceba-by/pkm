(ns webhooks.utils
  "Shared utilities for webhook handlers and tests.
   Contains pure helper functions for key generation, HMAC signature verification,
   webhook classification, document generation, and formatting."
  (:require [clojure.string :as str])
  (:import [javax.crypto Mac]
           [javax.crypto.spec SecretKeySpec]))

;; =============================================================================
;; Key Generation
;; =============================================================================

(defn source-pk
  "DynamoDB partition key for webhook sources"
  []
  "webhook_source")

(defn source-sk
  "DynamoDB sort key for a webhook source"
  [source-id]
  (str "source#" source-id))

(defn event-pk
  "DynamoDB partition key for webhook events"
  []
  "webhook_event")

(defn event-sk
  "DynamoDB sort key for a webhook event. Sorts chronologically by timestamp."
  [timestamp event-id]
  (str "event#" timestamp "#" event-id))

;; =============================================================================
;; HMAC Signature Verification
;; =============================================================================

(defn hmac-sha256-hex
  "Compute HMAC-SHA256 of body string with secret, return lowercase hex string."
  [secret body]
  (let [mac (Mac/getInstance "HmacSHA256")
        key-spec (SecretKeySpec. (.getBytes (str secret) "UTF-8") "HmacSHA256")]
    (.init mac key-spec)
    (let [bytes (.doFinal mac (.getBytes (str body) "UTF-8"))]
      (str/join (map #(format "%02x" (bit-and % 0xff)) bytes)))))

(defn constant-time-equals
  "Constant-time string comparison to prevent timing attacks."
  [a b]
  (when (and a b (= (count a) (count b)))
    (let [result (reduce (fn [acc [c1 c2]]
                           (bit-or acc (bit-xor (int c1) (int c2))))
                         0
                         (map vector a b))]
      (zero? result))))

(defn verify-github-signature
  "Verify GitHub webhook signature. Header format: 'sha256=<hex>'.
   Returns true if valid, false/nil otherwise."
  [secret raw-body signature-header]
  (when (and (not (str/blank? secret))
             (not (str/blank? raw-body))
             (not (str/blank? signature-header))
             (str/starts-with? signature-header "sha256="))
    (let [expected (str "sha256=" (hmac-sha256-hex secret raw-body))]
      (constant-time-equals expected signature-header))))

(defn verify-hmac-signature
  "Verify generic HMAC-SHA256 signature. Accepts raw hex or 'sha256=' prefixed.
   Returns true if valid, false/nil otherwise."
  [secret raw-body signature-header]
  (when (and (not (str/blank? secret))
             (not (str/blank? raw-body))
             (not (str/blank? signature-header)))
    (let [computed (hmac-sha256-hex secret raw-body)
          ;; Strip sha256= prefix if present
          provided (if (str/starts-with? signature-header "sha256=")
                     (subs signature-header 7)
                     signature-header)]
      (constant-time-equals computed provided))))

;; =============================================================================
;; Webhook Classification
;; =============================================================================

(defn- classify-github
  "Classify a GitHub webhook payload. Push events → document, others → event."
  [headers payload]
  (let [event-type (or (get headers "x-github-event") "unknown")]
    (case event-type
      "push" {:route :document
              :event-type "push"
              :title (str "Push to " (get-in payload [:repository :full_name]
                                             (get-in payload ["repository" "full_name"] "unknown")))}
      "release" {:route :document
                 :event-type "release"
                 :title (str "Release: " (get-in payload [:release :tag_name]
                                                 (get-in payload ["release" "tag_name"] "unknown")))}
      ;; All other GitHub events (issues, PRs, etc.) → event store
      {:route :event
       :event-type event-type
       :title (str "GitHub " event-type)})))

(defn- classify-email
  "Classify an email webhook payload. Emails always route to document."
  [_headers payload]
  (let [subject (or (get payload :subject) (get payload "subject") "No subject")]
    {:route :document
     :event-type "email"
     :title subject}))

(defn- classify-generic
  "Classify a generic/custom webhook payload. Default to event route."
  [_headers payload]
  {:route :event
   :event-type "custom"
   :title (or (get payload :title) (get payload "title") "Custom webhook")})

(defn classify-webhook
  "Classify webhook payload by source type. Returns map with :route (:document or :event),
   :event-type, and :title."
  [source-type headers payload]
  (case source-type
    "github" (classify-github headers payload)
    "email"  (classify-email headers payload)
    (classify-generic headers payload)))

;; =============================================================================
;; Document Generation
;; =============================================================================

(defn generate-document-path
  "Generate S3 key for a webhook-originated document.
   Format: _agent/webhooks/{source-id}/{YYYY-MM-DD}/{event-id}.md"
  [source-id event-id timestamp]
  (let [date-str (if (and timestamp (>= (count timestamp) 10))
                   (subs timestamp 0 10)
                   "unknown-date")]
    (str "_agent/webhooks/" source-id "/" date-str "/" event-id ".md")))

(defn- generate-github-body
  "Generate markdown body for a GitHub webhook event."
  [event-type payload]
  (let [repo (or (get-in payload [:repository :full_name])
                 (get-in payload ["repository" "full_name"])
                 "unknown")]
    (case event-type
      "push" (let [commits (or (get payload :commits) (get payload "commits") [])
                   ref (or (get payload :ref) (get payload "ref") "")]
               (str "**Repository:** " repo "\n"
                    "**Branch:** " ref "\n"
                    "**Commits:** " (count commits) "\n\n"
                    (str/join "\n" (map (fn [c]
                                          (str "- " (or (get c :message) (get c "message") "")))
                                        (take 10 commits)))))
      "release" (let [release (or (get payload :release) (get payload "release") {})
                      tag (or (get release :tag_name) (get release "tag_name") "")
                      body (or (get release :body) (get release "body") "")]
                  (str "**Repository:** " repo "\n"
                       "**Tag:** " tag "\n\n"
                       body))
      (str "**Repository:** " repo "\n"
           "**Event:** " event-type "\n"))))

(defn- generate-email-body
  "Generate markdown body for an email webhook."
  [payload]
  (let [from (or (get payload :from) (get payload "from") "unknown")
        to (or (get payload :to) (get payload "to") "unknown")
        body (or (get payload :body) (get payload "body")
                 (get payload :text) (get payload "text") "")]
    (str "**From:** " from "\n"
         "**To:** " to "\n\n"
         body)))

(defn- generate-generic-body
  "Generate markdown body for a generic webhook."
  [payload]
  (str "```edn\n"
       (pr-str payload)
       "\n```"))

(defn generate-markdown
  "Generate markdown content for a webhook payload."
  [source-type event-type event-id timestamp title payload]
  (let [frontmatter (str "---\n"
                         "source: " source-type "\n"
                         "event_type: " event-type "\n"
                         "webhook_id: " event-id "\n"
                         "received_at: " timestamp "\n"
                         "---\n\n")
        body (str "# " title "\n\n"
                  (case source-type
                    "github" (generate-github-body event-type payload)
                    "email"  (generate-email-body payload)
                    (generate-generic-body payload)))]
    (str frontmatter body)))

;; =============================================================================
;; API Response Formatting
;; =============================================================================

(defn format-source
  "Format a webhook source record for API response (snake_case → camelCase)."
  [source]
  {:id (:source_id source)
   :name (:name source)
   :sourceType (:source_type source)
   :status (:source_status source)
   :signingSecretArn (:signing_secret_arn source)
   :created (:created source)
   :modified (:modified source)})

(defn format-event
  "Format a webhook event record for API response."
  [event]
  {:id (:event_id event)
   :sourceId (:source_id event)
   :sourceType (:source_type event)
   :eventType (:event_type event)
   :route (:route event)
   :title (:title event)
   :status (:event_status event)
   :documentPath (:document_path event)
   :receivedAt (:received_at event)})
