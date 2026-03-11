(ns handler
  "Admin API: List webhook events.
   GET /admin/webhook-events"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [webhooks.utils :as wu]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn list-events
  "List recent webhook events, optionally filtered by source ID."
  [query-params]
  (let [source-id (or (get query-params :sourceId) (get query-params "sourceId"))
        limit (r/parse-int-param query-params :limit 50)
        results (ddb/query ddb-table
                           :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                           :expr-attr-values {":pk" (wu/event-pk)
                                               ":prefix" "event#"}
                           :scan-index-forward false
                           :limit limit)
        filtered (if source-id
                   (filter #(= source-id (:source_id %)) results)
                   results)]
    (r/ok {:events (mapv wu/format-event filtered)
           :count (count filtered)})))

(defn handler
  "Lambda handler for listing webhook events."
  [request]
  (try
    (let [event (json/parse-string (:body request) true)]
      (if-let [forbidden (r/require-admin event)]
        forbidden
        (let [query-params (r/parse-query-params event)]
          (println "Admin listing webhook events")
          (list-events query-params))))

    (catch Exception e
      (println "Error listing webhook events:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to list webhook events"))))
