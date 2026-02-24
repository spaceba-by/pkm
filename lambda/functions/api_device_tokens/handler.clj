(ns handler
  "API Lambda: Device token management for push notifications.
   Handles POST /devices and DELETE /devices/{device-id}"
  (:require [aws.dynamodb :as ddb]
            [aws.sns :as sns]
            [api.response :as r]
            [notifications.utils :as nu]
            [cheshire.core :as json])
  (:import [java.time Instant]
           [java.time.temporal ChronoUnit]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def sns-platform-arn (System/getenv "SNS_PLATFORM_APPLICATION_ARN"))

(defn- now-iso []
  (str (.truncatedTo (Instant/now) ChronoUnit/SECONDS)))

(defn register-device
  "Register or update a device token for push notifications.
   Creates an SNS platform endpoint server-side and stores the endpoint ARN."
  [user-sub body]
  (let [device-token (:deviceToken body)
        device-id (:deviceId body)
        platform (or (:platform body) "ios")
        app-version (or (:appVersion body) "unknown")
        now (now-iso)]

    (cond
      (nil? device-token)
      (r/bad-request "Device token is required")

      (nil? device-id)
      (r/bad-request "Device ID is required")

      (nil? sns-platform-arn)
      (r/internal-error "SNS platform application not configured")

      :else
      (let [endpoint-arn (sns/create-platform-endpoint sns-platform-arn device-token)
            item {:PK (nu/user-pk user-sub)
                  :SK (nu/device-sk device-id)
                  :endpoint_arn endpoint-arn
                  :device_id device-id
                  :platform platform
                  :app_version app-version
                  :registered_at now
                  :last_seen now}]
        (ddb/put-item ddb-table item)
        (r/ok-no-cache {:deviceId device-id
                        :registered true})))))

(defn unregister-device
  "Unregister a device from push notifications"
  [user-sub device-id]
  (let [pk (nu/user-pk user-sub)
        sk (nu/device-sk device-id)
        existing (ddb/get-item ddb-table {:PK pk :SK sk})]

    (if (nil? existing)
      (r/not-found (str "Device not found: " device-id))
      (do
        (ddb/delete-item ddb-table {:PK pk :SK sk})
        (r/ok-no-cache {:deleted true :deviceId device-id})))))

(defn handler
  "Lambda handler for device token CRUD operations"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)
          http-method (or (get-in event [:requestContext :http :method])
                          (get-in event ["requestContext" "http" "method"]))
          path-params (r/parse-path-params event)
          device-id (or (:device-id path-params) (get path-params "device-id"))

          request-body (when-let [body (or (:body event) (get event "body"))]
                         (if (string? body)
                           (json/parse-string body true)
                           body))]

      (println "User" user-sub "method:" http-method "device-id:" device-id)

      (case http-method
        "POST" (register-device user-sub request-body)
        "DELETE" (if device-id
                   (unregister-device user-sub device-id)
                   (r/bad-request "Device ID required"))
        (r/bad-request (str "Unsupported method: " http-method))))

    (catch Exception e
      (println "Error in device tokens API:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to process device token request"))))
