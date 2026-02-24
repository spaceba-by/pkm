(ns notifications.utils
  "Shared utilities for notification handlers and tests.
   Contains pure helper functions for key generation, formatting,
   and DynamoDB Stream record processing."
  (:require [cheshire.core :as json]))

;; =============================================================================
;; Key Generation
;; =============================================================================

(defn user-pk
  "Generate DynamoDB partition key for a user"
  [user-sub]
  (str "user#" user-sub))

(defn device-sk
  "Generate DynamoDB sort key for a device token"
  [device-id]
  (str "device_token#" device-id))

;; =============================================================================
;; Notification Formatting (API responses)
;; =============================================================================

(defn format-notification
  "Format a notification record for API response"
  [notification]
  {:notificationId (:notification_id notification)
   :notificationType (:notification_type notification)
   :title (or (:title notification)
              (case (:notification_type notification)
                "daily_summary" "Daily Summary"
                "weekly_report" "Weekly Report"
                "search_monitor" (str "Search Update: " (:monitor_name notification))
                "Notification"))
   :body (or (:body notification) "")
   :deepLink (:deep_link notification)
   :timestamp (:timestamp notification)
   :read (boolean (:read notification))})

;; =============================================================================
;; DynamoDB Stream Record Processing
;; =============================================================================

(defn notification-record?
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

(defn extract-notification-data
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

(defn build-apns-payload
  "Build APNs notification payload with a given badge count"
  [notification badge-count]
  (let [payload {:aps {:alert {:title (:title notification)
                               :body (:body notification)}
                       :sound "default"
                       :badge badge-count}
                 :notificationType (:notification-type notification)
                 :deepLink (:deep-link notification)
                 :notificationId (:notification-id notification)}]
    (json/generate-string payload)))
