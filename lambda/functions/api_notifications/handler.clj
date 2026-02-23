(ns handler
  "API Lambda: Notification management.
   Handles GET /notifications and PUT /notifications/{id}/read"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [notifications.utils :as nu]
            [cheshire.core :as json])
  (:import [java.time Instant]
           [java.time.temporal ChronoUnit]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn- now-iso []
  (str (.truncatedTo (Instant/now) ChronoUnit/SECONDS)))

(defn list-notifications
  "List all notifications for the user (both read and unread)"
  [user-sub]
  (let [pk (nu/user-pk user-sub)
        results (ddb/query ddb-table
                           :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                           :expr-attr-values {":pk" pk
                                               ":prefix" "notification#"}
                           :scan-index-forward false
                           :limit 50)
        formatted (mapv nu/format-notification results)]
    (r/ok {:notifications formatted
           :count (count formatted)})))

(defn mark-read
  "Mark a notification as read.
   Queries user notifications and filters by notification_id in-memory.
   For users with many notifications, consider adding a GSI on notification_id."
  [user-sub notification-id]
  (let [pk (nu/user-pk user-sub)
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
