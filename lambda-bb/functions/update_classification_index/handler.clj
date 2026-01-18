(ns handler
  "Lambda function to update the classification index"
  (:require [aws.s3 :as s3]
            [aws.dynamodb :as ddb]
            [markdown.utils :as md]
            [clojure.data.json :as json]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn handler
  "Lambda handler to update classification index in S3.
   This is typically invoked async from classify-document lambda"
  [event context]
  (try
    (println "Updating classification index")
    (println "Event:" (json/write-str event))

    ;; Get all classifications from DynamoDB
    (let [classifications (ddb/get-all-classifications ddb-table)]

      (println "Retrieved classifications for index update")

      ;; Create classification index markdown document
      (let [index-content (md/create-classification-index classifications)

            ;; Upload index to S3
            index-key (s3/put-agent-output s3-bucket
                                          "classifications"
                                          "index.md"
                                          index-content)]

        (println "Updated classification index:" index-key)

        ;; Count total documents
        (let [total-docs (reduce + (map count (vals classifications)))
              classification-counts (into {}
                                         (map (fn [[k v]] [k (count v)])
                                              classifications))]

          {:statusCode 200
           :body (json/write-str {:index-key index-key
                                  :total-documents total-docs
                                  :classifications classification-counts})})))

    (catch Exception e
      (println "Error updating classification index:" (.getMessage e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/write-str {:error (.getMessage e)})})))

;; For local testing
(defn -main [& args]
  (println "Running test update of classification index")
  (println "Result:" (handler {} nil)))
