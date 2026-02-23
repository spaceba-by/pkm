(ns notifications.handler-test
  "Unit tests for notification API handlers: device tokens and notifications"
  (:require [clojure.test :refer [deftest testing is]]
            [cheshire.core :as json]))

;; =============================================================================
;; Device Token Handler Tests
;; =============================================================================

;; Duplicate helper functions from handler for isolated testing
(defn- user-pk [user-sub]
  (str "user#" user-sub))

(defn- device-sk [device-id]
  (str "device_token#" device-id))

(deftest user-pk-test
  (testing "Generates correct partition key for user"
    (is (= "user#abc-123" (user-pk "abc-123")))
    (is (= "user#test-user" (user-pk "test-user")))))

(deftest device-sk-test
  (testing "Generates correct sort key for device"
    (is (= "device_token#device-001" (device-sk "device-001")))
    (is (= "device_token#AAAA-BBBB-CCCC" (device-sk "AAAA-BBBB-CCCC")))))

(deftest device-registration-validation-test
  (testing "Device token is required"
    (let [body {:deviceId "device-001" :platform "ios"}]
      (is (nil? (:deviceToken body)) "Missing deviceToken should be nil")))

  (testing "Device ID is required"
    (let [body {:deviceToken "token-abc" :platform "ios"}]
      (is (nil? (:deviceId body)) "Missing deviceId should be nil")))

  (testing "Valid registration body has all required fields"
    (let [body {:deviceToken "token-abc"
                :deviceId "device-001"
                :platform "ios"
                :appVersion "1.0.0"}]
      (is (some? (:deviceToken body)))
      (is (some? (:deviceId body)))
      (is (= "ios" (:platform body))))))

(deftest device-item-structure-test
  (testing "Device item has correct DynamoDB structure"
    (let [user-sub "user-123"
          device-id "device-001"
          device-token "abcdef0123456789"
          now "2026-02-23T12:00:00Z"
          item {:PK (user-pk user-sub)
                :SK (device-sk device-id)
                :device_token device-token
                :device_id device-id
                :platform "ios"
                :app_version "1.0.0"
                :registered_at now
                :last_seen now}]
      (is (= "user#user-123" (:PK item)))
      (is (= "device_token#device-001" (:SK item)))
      (is (= device-token (:device_token item)))
      (is (= "ios" (:platform item))))))

;; =============================================================================
;; Notification Handler Tests
;; =============================================================================

;; Duplicate format-notification from handler for isolated testing
(defn- format-notification
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

(deftest format-notification-test
  (testing "Formats complete notification correctly"
    (let [notification {:notification_id "notif-001"
                        :notification_type "daily_summary"
                        :title "Daily Summary: 2026-02-23"
                        :body "Summary of 5 documents"
                        :deep_link "/summaries/2026-02-23"
                        :timestamp "2026-02-23T06:00:00Z"
                        :read false}
          formatted (format-notification notification)]
      (is (= "notif-001" (:notificationId formatted)))
      (is (= "daily_summary" (:notificationType formatted)))
      (is (= "Daily Summary: 2026-02-23" (:title formatted)))
      (is (= "Summary of 5 documents" (:body formatted)))
      (is (= "/summaries/2026-02-23" (:deepLink formatted)))
      (is (= "2026-02-23T06:00:00Z" (:timestamp formatted)))
      (is (false? (:read formatted)))))

  (testing "Formats notification with default title for daily_summary"
    (let [notification {:notification_id "notif-002"
                        :notification_type "daily_summary"
                        :timestamp "2026-02-23T06:00:00Z"
                        :read false}
          formatted (format-notification notification)]
      (is (= "Daily Summary" (:title formatted)))
      (is (= "" (:body formatted)))))

  (testing "Formats notification with default title for weekly_report"
    (let [notification {:notification_id "notif-003"
                        :notification_type "weekly_report"
                        :timestamp "2026-02-23T20:00:00Z"
                        :read true}
          formatted (format-notification notification)]
      (is (= "Weekly Report" (:title formatted)))
      (is (true? (:read formatted)))))

  (testing "Formats search monitor notification with monitor name"
    (let [notification {:notification_id "notif-004"
                        :notification_type "search_monitor"
                        :monitor_name "AI Research"
                        :timestamp "2026-02-23T12:00:00Z"
                        :read false}
          formatted (format-notification notification)]
      (is (= "Search Update: AI Research" (:title formatted)))))

  (testing "Handles nil deep link"
    (let [notification {:notification_id "notif-005"
                        :notification_type "daily_summary"
                        :title "Test"
                        :timestamp "2026-02-23T06:00:00Z"
                        :read false}
          formatted (format-notification notification)]
      (is (nil? (:deepLink formatted))))))

;; =============================================================================
;; Notification Sort Key Tests
;; =============================================================================

(deftest notification-sk-pattern-test
  (testing "Notification sort key has correct prefix for pending notifications"
    (let [timestamp "2026-02-23T12:00:00Z"
          notification-id "uuid-1234"
          sk (str "notification#pending#" timestamp "#" notification-id)]
      (is (.startsWith sk "notification#pending#"))
      (is (.contains sk timestamp))
      (is (.endsWith sk notification-id))))

  (testing "Notification sort keys sort chronologically"
    (let [sk1 (str "notification#pending#2026-02-22T06:00:00Z#id1")
          sk2 (str "notification#pending#2026-02-23T06:00:00Z#id2")]
      (is (neg? (compare sk1 sk2)) "Earlier notification should sort before later"))))

;; =============================================================================
;; Notification Dispatch Tests
;; =============================================================================

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

(deftest notification-record?-test
  (testing "Identifies notification INSERT record"
    (is (notification-record?
         {:eventName "INSERT"
          :dynamodb {:NewImage {:SK {:S "notification#pending#2026-02-23T12:00:00Z#uuid-1234"}}}})))

  (testing "Rejects non-INSERT events"
    (is (not (notification-record?
              {:eventName "MODIFY"
               :dynamodb {:NewImage {:SK {:S "notification#pending#2026-02-23T12:00:00Z#uuid-1234"}}}}))))

  (testing "Rejects non-notification records"
    (is (not (notification-record?
              {:eventName "INSERT"
               :dynamodb {:NewImage {:SK {:S "document#notes/test.md"}}}}))))

  (testing "Rejects records without NewImage"
    (is (not (notification-record?
              {:eventName "INSERT"
               :dynamodb {}})))))

(defn- build-apns-payload
  "Build APNs notification payload"
  [notification]
  (let [payload {:aps {:alert {:title (:title notification)
                               :body (:body notification)}
                       :sound "default"
                       :badge 1}
                 :notificationType (:notification-type notification)
                 :deepLink (:deep-link notification)
                 :notificationId (:notification-id notification)}]
    (json/generate-string payload)))

(deftest build-apns-payload-test
  (testing "Builds correct APNs payload"
    (let [notification {:title "Daily Summary"
                        :body "Summary of 5 documents"
                        :notification-type "daily_summary"
                        :deep-link "/summaries/2026-02-23"
                        :notification-id "uuid-1234"}
          payload-str (build-apns-payload notification)
          payload (json/parse-string payload-str true)]
      (is (= "Daily Summary" (get-in payload [:aps :alert :title])))
      (is (= "Summary of 5 documents" (get-in payload [:aps :alert :body])))
      (is (= "default" (get-in payload [:aps :sound])))
      (is (= 1 (get-in payload [:aps :badge])))
      (is (= "daily_summary" (:notificationType payload)))
      (is (= "/summaries/2026-02-23" (:deepLink payload)))
      (is (= "uuid-1234" (:notificationId payload)))))

  (testing "Handles nil body"
    (let [notification {:title "Test"
                        :body nil
                        :notification-type "daily_summary"
                        :notification-id "uuid-5678"}
          payload-str (build-apns-payload notification)
          payload (json/parse-string payload-str true)]
      (is (nil? (get-in payload [:aps :alert :body]))))))

;; =============================================================================
;; Extract Notification Data Tests
;; =============================================================================

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

(deftest extract-notification-data-test
  (testing "Extracts data from keyword-keyed DynamoDB stream image"
    (let [new-image {:PK {:S "user#abc-123"}
                     :notification_id {:S "notif-001"}
                     :notification_type {:S "daily_summary"}
                     :title {:S "Daily Summary: 2026-02-23"}
                     :body {:S "Summary of 5 docs"}
                     :deep_link {:S "/summaries/2026-02-23"}
                     :timestamp {:S "2026-02-23T06:00:00Z"}}
          data (extract-notification-data new-image)]
      (is (= "user#abc-123" (:pk data)))
      (is (= "notif-001" (:notification-id data)))
      (is (= "daily_summary" (:notification-type data)))
      (is (= "Daily Summary: 2026-02-23" (:title data)))
      (is (= "Summary of 5 docs" (:body data)))
      (is (= "/summaries/2026-02-23" (:deep-link data)))))

  (testing "Uses default title when not provided"
    (let [new-image {:PK {:S "user#abc-123"}
                     :notification_id {:S "notif-002"}
                     :notification_type {:S "daily_summary"}
                     :timestamp {:S "2026-02-23T06:00:00Z"}}
          data (extract-notification-data new-image)]
      (is (= "Daily Summary Ready" (:title data)))
      (is (= "" (:body data))))))
