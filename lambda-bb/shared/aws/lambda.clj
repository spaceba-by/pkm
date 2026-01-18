(ns aws.lambda
  "Lambda invocation utilities using awyeah client"
  (:require [com.grzm.awyeah.client.api :as aws]
            [cheshire.core :as json]))

(defonce ^:private lambda-client
  (delay (aws/client {:api :lambda})))

(defn- check-error
  "Check AWS response for errors and throw if found"
  [response operation]
  (when-let [error-category (:cognitect.anomalies/category response)]
    (throw (ex-info (str "Lambda " operation " failed: "
                         (or (:message response) error-category))
                    {:operation operation
                     :error-category error-category
                     :error-code (:cognitect.aws.error/code response)
                     :response response})))
  response)

(defn invoke-async
  "Asynchronously invokes another Lambda function (fire and forget)"
  [function-name payload]
  (-> (aws/invoke @lambda-client
                  {:op :Invoke
                   :request {:FunctionName function-name
                            :InvocationType "Event"
                            :Payload (.getBytes (json/generate-string payload) "UTF-8")}})
      (check-error "Invoke")))

(defn invoke-sync
  "Synchronously invokes another Lambda function and returns response"
  [function-name payload]
  (let [response (-> (aws/invoke @lambda-client
                                 {:op :Invoke
                                  :request {:FunctionName function-name
                                           :InvocationType "RequestResponse"
                                           :Payload (.getBytes (json/generate-string payload) "UTF-8")}})
                     (check-error "Invoke"))]
    (when-let [payload-bytes (:Payload response)]
      (json/parse-string (slurp payload-bytes) true))))
