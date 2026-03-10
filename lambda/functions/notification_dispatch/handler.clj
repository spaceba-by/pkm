(ns handler
  "Lambda function: Dispatch push notifications via SNS/APNs.
   Triggered by DynamoDB Stream when notification records are written."
  (:require [aws.dynamodb :as ddb]
            [aws.sns :as sns]
            [notifications.utils :as nu]
            [cheshire.core :as json])
  (:import [java.time Instant]
           [java.time.temporal ChronoUnit]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def sns-platform-arn (System/getenv "SNS_PLATFORM_APPLICATION_ARN"))

(defn- now-iso []
  (str (.truncatedTo (Instant/now) ChronoUnit/SECONDS)))

(defn- get-user-device-tokens
  "Get all registered device tokens for a user"
  [user-pk]
  (ddb/query ddb-table
             :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
             :expr-attr-values {":pk" user-pk
                                 ":prefix" "device_token#"}))

(defn- insight-pk-from-user-pk
  "Convert user PK (user#sub) to insight PK (insight#sub)"
  [user-pk]
  (str "insight#" (subs user-pk (count "user#"))))

(defn- get-unviewed-insight-count
  "Get count of unviewed insight records for a specific user"
  [user-pk]
  (let [items (ddb/query ddb-table
                         :key-condition-expr "PK = :pk"
                         :expr-attr-values {":pk" (insight-pk-from-user-pk user-pk)})]
    (count (filter (fn [item]
                     (let [viewed-at (:viewed_at item)
                           modified-at (:modified_at item)]
                       (or (nil? viewed-at)
                           (pos? (compare modified-at viewed-at)))))
                   items))))

(defn- send-to-device
  "Send notification to a single device via SNS using the server-created endpoint ARN"
  [device apns-payload]
  (let [endpoint-arn (:endpoint_arn device)]
    (if (nil? endpoint-arn)
      (println "Skipping device" (:device_id device) "- no endpoint ARN")
      (try
        (let [message (json/generate-string
                       {"APNS" apns-payload
                        "APNS_SANDBOX" apns-payload})]
          (sns/publish-to-endpoint endpoint-arn message)
          (println "Sent notification to device:" (:device_id device)))
        (catch Exception e
          (println "Error sending to device" (:device_id device) ":" (ex-message e))
          (when-let [data (ex-data e)]
            (println "Error details:" (pr-str data))))))))

(defn process-record
  "Process a single DynamoDB Stream record"
  [record]
  (when (nu/notification-record? record)
    (let [new-image (or (get-in record [:dynamodb :NewImage])
                        (get-in record ["dynamodb" "NewImage"]))
          notification (nu/extract-notification-data new-image)
          user-pk (:pk notification)
          device-tokens (get-user-device-tokens user-pk)
          ;; Compute badge count once per notification, scoped to user
          badge-count (try (get-unviewed-insight-count user-pk)
                           (catch Exception _ 1))
          apns-payload (nu/build-apns-payload notification badge-count)]

      (println "Dispatching notification:" (:notification-id notification)
               "type:" (:notification-type notification)
               "to" (count device-tokens) "devices"
               "badge:" badge-count)

      (doseq [device device-tokens]
        (send-to-device device apns-payload))

      {:notification-id (:notification-id notification)
       :devices-notified (count device-tokens)})))

(defn handler
  "Lambda handler for DynamoDB Stream trigger.
   The bblf runtime wraps the raw Lambda event as a JSON string in :body."
  [request]
  (try
    (let [event (if (string? (:body request))
                  (json/parse-string (:body request) true)
                  request)
          records (or (:Records event) [])]

      (println "Processing" (count records) "DynamoDB Stream records")

      (let [results (keep process-record records)]
        {:processed (count results)
         :results (vec results)}))

    (catch Exception e
      (println "Error in notification dispatch:" (ex-message e))
      (.printStackTrace e)
      (throw e))))
