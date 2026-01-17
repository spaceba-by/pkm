(ns aws.s3
  "S3 operations using awyeah client"
  (:require [com.grzm.awyeah.client.api :as aws]))

(defonce ^:private s3-client
  (delay (aws/client {:api :s3})))

(defn get-object
  "Downloads object from S3 bucket and returns content as string"
  [bucket key]
  (let [response (aws/invoke @s3-client
                             {:op :GetObject
                              :request {:Bucket bucket
                                       :Key key}})]
    (if-let [body (:Body response)]
      (slurp body)
      (throw (ex-info "S3 object not found or empty"
                      {:bucket bucket
                       :key key
                       :error (:cognitect.anomalies/category response)
                       :message (:Message response)})))))

(defn put-object
  "Uploads string content to S3 bucket"
  [bucket key content]
  (aws/invoke @s3-client
              {:op :PutObject
               :request {:Bucket bucket
                        :Key key
                        :Body (.getBytes content "UTF-8")}}))

(defn object-exists?
  "Check if S3 object exists"
  [bucket key]
  (try
    (aws/invoke @s3-client
                {:op :HeadObject
                 :request {:Bucket bucket
                          :Key key}})
    true
    (catch Exception _ false)))

(defn delete-object
  "Deletes object from S3 bucket"
  [bucket key]
  (aws/invoke @s3-client
              {:op :DeleteObject
               :request {:Bucket bucket
                        :Key key}}))

(defn list-objects
  "Lists objects with given prefix"
  [bucket prefix]
  (let [response (aws/invoke @s3-client
                             {:op :ListObjectsV2
                              :request {:Bucket bucket
                                       :Prefix prefix}})]
    (map :Key (:Contents response))))

(defn get-object-metadata
  "Gets object metadata without downloading content"
  [bucket key]
  (let [response (aws/invoke @s3-client
                             {:op :HeadObject
                              :request {:Bucket bucket
                                       :Key key}})]
    {:last-modified (:LastModified response)
     :content-length (:ContentLength response)
     :content-type (:ContentType response)
     :etag (:ETag response)}))

(defn put-agent-output
  "Upload agent-generated content to S3 _agent/ directory.
   Returns the S3 key where content was uploaded"
  [bucket output-type filename content]
  (let [key (str "_agent/" output-type "/" filename)]
    (put-object bucket key content)
    (println "Uploaded agent output:" key)
    key))

(defn get-daily-summary
  "Retrieve daily summary for a specific date"
  [bucket date-str]
  (let [key (str "_agent/summaries/" date-str ".md")]
    (try
      (get-object bucket key)
      (catch Exception _
        nil))))
