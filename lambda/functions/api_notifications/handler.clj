(ns handler
  "API Lambda: Notification management.
   Handles GET /notifications and PUT /notifications/{id}/read"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.time Instant]
           [java.time.temporal ChronoUnit]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn- now-iso []
  (str (.truncatedTo (Instant/now) ChronoUnit/SECONDS)))

(defn- user-pk [user-sub]
  (str "user#" user-sub))

(defn- format-notification
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

(defn list-notifications
  "List pending notifications for the user"
  [user-sub]
  (let [pk (user-pk user-sub)
        results (ddb/query ddb-table
                           :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                           :expr-attr-values {":pk" pk
                                               ":prefix" "notification#"}
                           :scan-index-forward false
                           :limit 50)
        formatted (mapv format-notification results)]
    (r/ok {:notifications formatted
           :count (count formatted)})))

(defn mark-read
  "Mark a notification as read"
  [user-sub notification-id]
  (let [pk (user-pk user-sub)
        ;; Find the notification by scanning pending notifications
        results (ddb/query ddb-table
                           :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                           :expr-attr-values {":pk" pk
                                               ":prefix" "notification#"})
        target (first (filter #(= notification-id (:notification_id %)) results))]

    (if (nil? target)
      (r/not-found (str "Notification not found: " notification-id))
      (do
        (ddb/update-item-attrs ddb-table
                               {:PK pk :SK (:SK target)}
                               {:read true})
        (r/ok-no-cache {:notificationId notification-id
                        :read true})))))

(defn handler
  "Lambda handler for notification operations"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)
          http-method (or (get-in event [:requestContext :http :method])
                          (get-in event ["requestContext" "http" "method"]))
          path-params (r/parse-path-params event)
          notification-id (or (:id path-params) (get path-params "id"))]

      (println "User" user-sub "method:" http-method "notification-id:" notification-id)

      (case http-method
        "GET" (list-notifications user-sub)
        "PUT" (if notification-id
                (mark-read user-sub notification-id)
                (r/bad-request "Notification ID required"))
        (r/bad-request (str "Unsupported method: " http-method))))

    (catch Exception e
      (println "Error in notifications API:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to process notification request"))))
