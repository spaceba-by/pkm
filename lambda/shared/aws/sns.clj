(ns aws.sns
  "SNS client for push notification dispatch using awyeah client"
  (:require [com.grzm.awyeah.client.api :as aws]))

(defonce ^:private sns-client
  (delay (aws/client {:api :sns})))

(defn- check-error
  "Check AWS response for errors and throw if found"
  [response operation]
  (when-let [error-category (:cognitect.anomalies/category response)]
    (throw (ex-info (str "SNS " operation " failed: "
                         (or (:message response) error-category))
                    {:operation operation
                     :error-category error-category
                     :error-code (:cognitect.aws.error/code response)
                     :response response})))
  response)

(defn publish-to-endpoint
  "Publish a message to a specific platform endpoint (device token).
   Message should be a JSON string with platform-specific keys."
  [endpoint-arn message]
  (-> (aws/invoke @sns-client
                  {:op :Publish
                   :request {:TargetArn endpoint-arn
                             :Message message
                             :MessageStructure "json"}})
      (check-error "Publish")))

(defn create-platform-endpoint
  "Create a platform endpoint for a device token"
  [platform-application-arn device-token]
  (let [response (-> (aws/invoke @sns-client
                                 {:op :CreatePlatformEndpoint
                                  :request {:PlatformApplicationArn platform-application-arn
                                            :Token device-token}})
                     (check-error "CreatePlatformEndpoint"))]
    (:EndpointArn response)))
