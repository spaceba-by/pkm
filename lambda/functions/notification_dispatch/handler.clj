(ns handler
  "Lambda function: Dispatch push notifications via SNS/APNs.
   Triggered by DynamoDB Stream when notification records are written."
  (:require [aws.dynamodb :as ddb]
            [aws.sns :as sns]
            [cheshire.core :as json])
  (:import [java.time Instant]
           [java.time.temporal ChronoUnit]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def sns-platform-arn (System/getenv "SNS_PLATFORM_APPLICATION_ARN"))

(defn- now-iso []
  (str (.truncatedTo (Instant/now) ChronoUnit/SECONDS)))

(defn- notification-record?
  "Check if a DynamoDB Stream record is a new notification record"
  [record]
  (let [event-name (or (:eventName record) (get record "eventName"))
        new-image (or (get-in record [:dynamodb :NewImage])
                      (get-in record ["dynamodb" "NewImage"]))]
    (and (= "INSERT" event-name)
         new-image
         (let [sk-val (or (get-in new-image [:SK :S])
                          (get-in new-image ["SK" "S"])
                          "")]
           (.startsWith sk-val "notification#pending#")))))

(defn- extract-notification-data
  "Extract notification data from DynamoDB Stream new image"
  [new-image]
  (let [get-s (fn [field] (or (get-in new-image [field :S])
                               (get-in new-image [(name field) "S"])))]
    {:pk (get-s :PK)
     :notification-id (get-s :notification_id)
     :notification-type (get-s :notification_type)
     :title (or (get-s :title)
                (case (get-s :notification_type)
                  "daily_summary" "Daily Summary Ready"
                  "weekly_report" "Weekly Report Ready"
                  "search_monitor" (str "Search Update: " (get-s :monitor_name))
                  "New Notification"))
     :body (or (get-s :body) "")
     :deep-link (get-s :deep_link)
     :timestamp (get-s :timestamp)}))

(defn- get-user-device-tokens
  "Get all registered device tokens for a user"
  [user-pk]
  (ddb/query ddb-table
             :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
             :expr-attr-values {":pk" user-pk
                                 ":prefix" "device_token#"}))

(defn- get-unread-count
  "Get unread notification count for a user"
  [user-pk]
  (let [results (ddb/query ddb-table
                           :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                           :expr-attr-values {":pk" user-pk
                                               ":prefix" "notification#pending#"}
                           :select "COUNT")]
    (or results 0)))

(defn- build-apns-payload
  "Build APNs notification payload"
  [notification]
  (let [badge-count (try (get-unread-count (:pk notification))
                         (catch Exception _ 1))
        payload {:aps {:alert {:title (:title notification)
                               :body (:body notification)}
                       :sound "default"
                       :badge badge-count}
                 :notificationType (:notification-type notification)
                 :deepLink (:deep-link notification)
                 :notificationId (:notification-id notification)}]
    (json/generate-string payload)))

(defn- send-to-device
  "Send notification to a single device via SNS using the server-created endpoint ARN"
  [device notification]
  (let [endpoint-arn (:endpoint_arn device)]
    (if (nil? endpoint-arn)
      (println "Skipping device" (:device_id device) "- no endpoint ARN")
      (try
        (let [apns-payload (build-apns-payload notification)
              message (json/generate-string
                       {"APNS" apns-payload
                        "APNS_SANDBOX" apns-payload
                        "default" (:title notification)})]
          (sns/publish-to-endpoint endpoint-arn message)
          (println "Sent notification to device:" (:device_id device)))
        (catch Exception e
          (println "Error sending to device" (:device_id device) ":" (ex-message e)))))))

(defn process-record
  "Process a single DynamoDB Stream record"
  [record]
  (when (notification-record? record)
    (let [new-image (or (get-in record [:dynamodb :NewImage])
                        (get-in record ["dynamodb" "NewImage"]))
          notification (extract-notification-data new-image)
          device-tokens (get-user-device-tokens (:pk notification))]

      (println "Dispatching notification:" (:notification-id notification)
               "type:" (:notification-type notification)
               "to" (count device-tokens) "devices")

      (doseq [device device-tokens]
        (send-to-device device notification))

      {:notification-id (:notification-id notification)
       :devices-notified (count device-tokens)})))

(defn handler
  "Lambda handler for DynamoDB Stream trigger.
   DynamoDB Stream events contain Records directly in the event (not in a body)."
  [request]
  (try
    (let [records (or (:Records request) (get request "Records") [])]

      (println "Processing" (count records) "DynamoDB Stream records")

      (let [results (keep process-record records)]
        {:processed (count results)
         :results (vec results)}))

    (catch Exception e
      (println "Error in notification dispatch:" (ex-message e))
      (.printStackTrace e)
      (throw e))))
