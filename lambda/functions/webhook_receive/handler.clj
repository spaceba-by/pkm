(ns handler
  "Public webhook receiver. POST /webhooks/{source-id}
   No JWT auth — signature-verified instead.
   Validates payload, classifies by source type, and routes to
   S3 (_agent/webhooks/) for document storage or DynamoDB for events."
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [aws.secrets-manager :as sm]
            [api.response :as r]
            [webhooks.utils :as wu]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.time Instant]
           [java.time.temporal ChronoUnit]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn- now-iso []
  (str (.truncatedTo (Instant/now) ChronoUnit/SECONDS)))

(defn- get-header
  "Case-insensitive header lookup. API Gateway v2 lowercases all header names."
  [headers header-name]
  (or (get headers (str/lower-case header-name))
      (get headers header-name)))

(defn- lookup-source
  "Fetch webhook source configuration from DynamoDB."
  [source-id]
  (ddb/get-item ddb-table {:PK (wu/source-pk) :SK (wu/source-sk source-id)}))

(defn- verify-signature
  "Verify request signature using source-specific method.
   Returns nil on success, error string on failure."
  [source raw-body headers]
  (let [secret-arn (:signing_secret_arn source)
        source-type (:source_type source)]
    (if (str/blank? secret-arn)
      "Source has no signing secret configured"
      (let [secret (sm/get-secret-value secret-arn)
            sig-header (case source-type
                         "github" (get-header headers "x-hub-signature-256")
                         (get-header headers "x-webhook-signature"))]
        (if (str/blank? sig-header)
          "Missing signature header"
          (let [valid? (case source-type
                         "github" (wu/verify-github-signature secret raw-body sig-header)
                         (wu/verify-hmac-signature secret raw-body sig-header))]
            (when-not valid?
              "Invalid signature")))))))

(defn- record-event
  "Write webhook event record to DynamoDB for audit trail."
  [source-id source-type event-id event-type route title document-path timestamp]
  (ddb/put-item ddb-table
                {:PK (wu/event-pk)
                 :SK (wu/event-sk timestamp event-id)
                 :event_id event-id
                 :source_id source-id
                 :source_type source-type
                 :event_type event-type
                 :route (name route)
                 :title title
                 :event_status "received"
                 :document_path (or document-path "")
                 :received_at timestamp}))

(defn- route-to-document
  "Write payload as markdown to S3 under _agent/webhooks/."
  [source-id source-type event-id timestamp classification payload]
  (let [doc-path (wu/generate-document-path source-id event-id timestamp)
        content (wu/generate-markdown source-type
                                       (:event-type classification)
                                       event-id timestamp
                                       (:title classification)
                                       payload)]
    (s3/put-object s3-bucket doc-path content)
    (println "Wrote webhook document:" doc-path)
    doc-path))

(defn handler
  "Lambda handler for POST /webhooks/{source-id}"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          path-params (r/parse-path-params event)
          source-id (or (:source-id path-params) (get path-params "source-id"))
          headers (or (:headers event) (get event "headers") {})
          raw-body (or (:body event) (get event "body") "")]

      (println "Webhook received for source:" source-id)

      (if (str/blank? source-id)
        (r/bad-request "source-id is required")

        (let [source (lookup-source source-id)]
          (if (nil? source)
            (r/not-found "Unknown webhook source")

            (if (not= "active" (:source_status source))
              (r/bad-request "Webhook source is not active")

              (if-let [sig-error (verify-signature source raw-body headers)]
                (do
                  (println "Signature verification failed for" source-id ":" sig-error)
                  {:statusCode 401
                   :headers {"Content-Type" "application/json"}
                   :body (json/generate-string {:error "Unauthorized" :message sig-error})})

                (let [payload (if (string? raw-body)
                                (try (json/parse-string raw-body true)
                                     (catch Exception _ {:raw raw-body}))
                                raw-body)
                      source-type (:source_type source)
                      event-id (str (java.util.UUID/randomUUID))
                      timestamp (now-iso)
                      classification (wu/classify-webhook source-type headers payload)
                      route (:route classification)
                      doc-path (when (= :document route)
                                 (route-to-document source-id source-type
                                                     event-id timestamp
                                                     classification payload))]

                    ;; Record audit event
                    (record-event source-id source-type event-id
                                  (:event-type classification)
                                  route (:title classification)
                                  doc-path timestamp)

                    (println "Webhook processed:" source-id "route:" (name route))
                    {:statusCode 200
                     :headers {"Content-Type" "application/json"}
                     :body (json/generate-string {:received true
                                                  :eventId event-id})})))))))

    (catch Exception e
      (println "Error processing webhook:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to process webhook"))))
