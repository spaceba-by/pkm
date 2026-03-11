(ns handler
  "Admin API: CRUD for webhook source configuration.
   POST/GET /admin/webhook-sources, PUT/DELETE /admin/webhook-sources/{id}"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [webhooks.utils :as wu]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.time Instant]
           [java.time.temporal ChronoUnit]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(def valid-source-types #{"github" "email" "custom"})
(def valid-statuses #{"active" "paused"})

(defn- now-iso []
  (str (.truncatedTo (Instant/now) ChronoUnit/SECONDS)))

(defn create-source
  "Register a new webhook source."
  [body]
  (let [source-id (str (java.util.UUID/randomUUID))
        name (get body :name)
        source-type (get body :sourceType)
        signing-secret-arn (get body :signingSecretArn)
        now (now-iso)]
    (cond
      (str/blank? name)
      (r/bad-request "name is required")

      (not (valid-source-types source-type))
      (r/bad-request (str "sourceType must be one of: " (str/join ", " (sort valid-source-types))))

      (str/blank? signing-secret-arn)
      (r/bad-request "signingSecretArn is required")

      :else
      (let [item {:PK (wu/source-pk)
                  :SK (wu/source-sk source-id)
                  :source_id source-id
                  :name name
                  :source_type source-type
                  :source_status "active"
                  :signing_secret_arn signing-secret-arn
                  :created now
                  :modified now}]
        (ddb/put-item ddb-table item)
        (r/created (wu/format-source item))))))

(defn list-sources
  "List all registered webhook sources."
  []
  (let [results (ddb/query-all ddb-table
                               :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                               :expr-attr-values {":pk" (wu/source-pk)
                                                   ":prefix" "source#"})]
    (r/ok {:sources (mapv wu/format-source results)
           :count (count results)})))

(defn update-source
  "Update an existing webhook source."
  [source-id body]
  (let [existing (ddb/get-item ddb-table {:PK (wu/source-pk) :SK (wu/source-sk source-id)})]
    (if (nil? existing)
      (r/not-found (str "Source not found: " source-id))

      (let [now (now-iso)
            updates (cond-> {:modified now}
                      (:name body) (assoc :name (:name body))
                      (:status body) (assoc :source_status (:status body))
                      (:signingSecretArn body) (assoc :signing_secret_arn (:signingSecretArn body)))]
        (cond
          (and (:name body) (str/blank? (:name body)))
          (r/bad-request "name must not be blank")

          (and (:status body) (not (valid-statuses (:status body))))
          (r/bad-request (str "status must be one of: " (str/join ", " (sort valid-statuses))))

          :else
          (let [updated (ddb/update-item-attrs ddb-table
                                                {:PK (wu/source-pk) :SK (wu/source-sk source-id)}
                                                updates)]
            (r/ok-no-cache (wu/format-source updated))))))))

(defn delete-source
  "Delete a webhook source."
  [source-id]
  (let [existing (ddb/get-item ddb-table {:PK (wu/source-pk) :SK (wu/source-sk source-id)})]
    (if (nil? existing)
      (r/not-found (str "Source not found: " source-id))
      (do
        (ddb/delete-item ddb-table {:PK (wu/source-pk) :SK (wu/source-sk source-id)})
        (r/ok-no-cache {:deleted true :id source-id})))))

(defn handler
  "Lambda handler for webhook source CRUD operations."
  [request]
  (try
    (let [event (json/parse-string (:body request) true)]
      (if-let [forbidden (r/require-admin event)]
        forbidden
        (let [http-method (or (get-in event [:requestContext :http :method])
                              (get-in event ["requestContext" "http" "method"]))
              path-params (r/parse-path-params event)
              source-id (or (:id path-params) (get path-params "id"))
              request-body (when-let [body (or (:body event) (get event "body"))]
                             (if (string? body)
                               (json/parse-string body true)
                               body))]

          (println "Admin webhook-sources method:" http-method "source-id:" source-id)

          (case http-method
            "POST" (create-source request-body)
            "GET" (list-sources)
            "PUT" (if source-id
                    (update-source source-id request-body)
                    (r/bad-request "Source ID required"))
            "DELETE" (if source-id
                       (delete-source source-id)
                       (r/bad-request "Source ID required"))
            (r/bad-request (str "Unsupported method: " http-method))))))

    (catch Exception e
      (println "Error in webhook-sources API:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to process webhook source request"))))
