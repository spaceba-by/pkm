(ns handler
  "API Lambda: Trigger bulk reclassification asynchronously"
  (:require [aws.lambda :as lambda]
            [api.response :as r]
            [cheshire.core :as json]))

(def bulk-reclassify-lambda (System/getenv "BULK_RECLASSIFY_LAMBDA"))

(defn handler
  "Lambda handler for POST /admin/reclassify"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)

          ;; Parse request body
          request-body (when-let [body (or (:body event) (get event "body"))]
                         (if (string? body)
                           (json/parse-string body true)
                           body))
          classification (:classification request-body)
          dry-run (boolean (:dry_run request-body))

          _ (println "User" user-sub "triggering bulk reclassify"
                     "classification:" classification "dry_run:" dry-run)]

      (if dry-run
        ;; For dry run, invoke synchronously to return counts
        (let [result (lambda/invoke-sync
                       bulk-reclassify-lambda
                       {:body (json/generate-string
                               {:classification classification
                                :dry_run true})})]
          (r/ok-no-cache (json/parse-string (:body result) true)))

        ;; For actual reclassification, invoke async and return immediately
        (do
          (lambda/invoke-async
            bulk-reclassify-lambda
            {:body (json/generate-string
                    {:classification classification
                     :dry_run false})})
          (r/ok-no-cache {:status "triggered"
                          :message "Bulk reclassification started"
                          :classification_filter classification}))))

    (catch Exception e
      (println "Error triggering bulk reclassify:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to trigger bulk reclassification"))))
