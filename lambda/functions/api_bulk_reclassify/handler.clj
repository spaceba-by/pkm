(ns handler
  "API Lambda: Trigger bulk reclassification asynchronously"
  (:require [aws.lambda :as lambda]
            [api.response :as r]
            [cheshire.core :as json]))

(def bulk-reclassify-lambda (System/getenv "BULK_RECLASSIFY_LAMBDA"))

(defn handler
  "Lambda handler for POST /admin/reclassify.
   Both dry-run and execute modes invoke bulk_reclassify asynchronously
   to avoid API Gateway timeout (30s) on large vaults."
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

      ;; Always invoke async to avoid timeout on large vaults.
      ;; For dry-run, check results in CloudWatch logs or invoke
      ;; the bulk_reclassify Lambda directly via CLI.
      (lambda/invoke-async
        bulk-reclassify-lambda
        {:body (json/generate-string
                {:classification classification
                 :dry_run dry-run})})

      (r/ok-no-cache {:status "triggered"
                      :message (if dry-run
                                 "Bulk reclassification dry-run started"
                                 "Bulk reclassification started")
                      :dry_run dry-run
                      :classification_filter classification}))

    (catch Exception e
      (println "Error triggering bulk reclassify:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to trigger bulk reclassification"))))
