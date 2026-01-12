(ns aws.lambda
  "Lambda invocation utilities using awwyeah client"
  (:require [awyeah.client.api :as aws]
            [clojure.data.json :as json]))

(defonce ^:private lambda-client
  (delay (aws/client {:api :lambda})))

(defn invoke-async
  "Asynchronously invokes another Lambda function (fire and forget)"
  [function-name payload]
  (aws/invoke @lambda-client
              {:op :Invoke
               :request {:FunctionName function-name
                        :InvocationType "Event"  ; Async invocation
                        :Payload (.getBytes (json/write-str payload) "UTF-8")}}))

(defn invoke-sync
  "Synchronously invokes another Lambda function and returns response"
  [function-name payload]
  (let [response (aws/invoke @lambda-client
                             {:op :Invoke
                              :request {:FunctionName function-name
                                       :InvocationType "RequestResponse"  ; Sync invocation
                                       :Payload (.getBytes (json/write-str payload) "UTF-8")}})]
    (when-let [payload-bytes (:Payload response)]
      (json/read-str (slurp payload-bytes) :key-fn keyword))))
