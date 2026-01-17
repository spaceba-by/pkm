(ns handler
  "Lambda function to generate daily summaries of PKM activity"
  (:require [aws.s3 :as s3]
            [aws.dynamodb :as ddb]
            [aws.bedrock :as bedrock]
            [markdown.utils :as md]
            [clojure.data.json :as json])
  (:import [java.time Instant ZonedDateTime ZoneOffset Duration]
           [java.time.format DateTimeFormatter]
           [java.time.temporal ChronoUnit]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def bedrock-model (System/getenv "BEDROCK_MODEL_ID"))

(def ^:private date-formatter (DateTimeFormatter/ofPattern "yyyy-MM-dd"))

(defn- format-date
  "Format an Instant as yyyy-MM-dd"
  [inst]
  (.format (.atZone inst ZoneOffset/UTC) date-formatter))

(defn- parse-instant
  "Parse a date string to Instant"
  [date-str]
  (Instant/parse date-str))

(defn- minus-days
  "Subtract days from an Instant"
  [inst days]
  (.minus inst (Duration/ofDays days)))

(defn- plus-days
  "Add days to an Instant"
  [inst days]
  (.plus inst (Duration/ofDays days)))

(defn- truncate-to-day
  "Truncate Instant to start of day (UTC)"
  [inst]
  (.truncatedTo inst ChronoUnit/DAYS))

(defn get-target-date
  "Get target date from event or default to yesterday"
  [event]
  (if-let [date-str (:date event)]
    (parse-instant date-str)
    ;; Default to yesterday (summary runs at 6 AM for previous day)
    (minus-days (Instant/now) 1)))

(defn filter-day-docs
  "Filter documents to those within target day"
  [docs since-iso until-iso]
  (filter (fn [doc]
            (let [modified (or (:modified doc) "")]
              (and (>= (compare modified since-iso) 0)
                   (< (compare modified until-iso) 0))))
          docs))

(defn retrieve-document-content
  "Retrieve full content for documents"
  [docs max-docs]
  (println "Retrieving content for" (min (count docs) max-docs) "documents")
  (loop [remaining (take max-docs docs)
         documents []]
    (if (empty? remaining)
      documents
      (let [doc (first remaining)
            doc-path (:pk doc)]

        ;; Skip agent-generated documents
        (if (.startsWith doc-path "_agent/")
          (recur (rest remaining) documents)

          (let [result (try
                         (let [content (s3/get-object s3-bucket doc-path)]
                           (when (and content (not (empty? content)))
                             {:path doc-path
                              :content (subs content 0 (min 2000 (count content)))
                              :title (or (:title doc) "Untitled")}))
                         (catch Exception e
                           (println "Error retrieving" doc-path ":" (.getMessage e))
                           nil))]
            (recur (rest remaining)
                   (if result
                     (conj documents result)
                     documents))))))))

(defn handler
  "Lambda handler for scheduled EventBridge event"
  [event context]
  (try
    (println "Generating daily summary")

    ;; Get target date
    (let [target-date (get-target-date event)
          date-str (format-date target-date)
          _ (println "Target date:" date-str)

          ;; Calculate day boundaries
          since (truncate-to-day target-date)
          until (plus-days since 1)
          since-iso (str since)
          until-iso (str until)]

      (println "Querying documents modified between" since-iso "and" until-iso)

      ;; Query documents modified since start of target day
      (let [recent-docs (ddb/get-documents-modified-since ddb-table since-iso :limit 1000)

            ;; Filter to documents within target day
            day-docs (filter-day-docs recent-docs since-iso until-iso)

            _ (println "Found" (count day-docs) "documents for" date-str)]

        (if (empty? day-docs)
          (do
            (println "No documents to summarize")
            {:statusCode 200
             :body (json/write-str {:message "No documents to summarize"
                                    :date date-str})})

          ;; Retrieve document content
          (let [documents (retrieve-document-content day-docs 20)]

            (if (empty? documents)
              (do
                (println "No valid documents to summarize")
                {:statusCode 200
                 :body (json/write-str {:message "No valid documents to summarize"
                                        :date date-str})})

              (do
                (println "Summarizing" (count documents) "documents")

                ;; Generate summary using Bedrock
                (let [summary-content (bedrock/generate-summary bedrock-model documents)

                      ;; Create summary document
                      source-paths (mapv :path documents)
                      summary-doc (md/create-summary-document date-str
                                                             summary-content
                                                             source-paths
                                                             (count documents))

                      ;; Upload summary to S3
                      summary-key (s3/put-agent-output s3-bucket
                                                       "summaries"
                                                       (str date-str ".md")
                                                       summary-doc)]

                  (println "Created daily summary:" summary-key)

                  {:statusCode 200
                   :body (json/write-str {:date date-str
                                          :summary-key summary-key
                                          :document-count (count documents)})})))))))

    (catch Exception e
      (println "Error generating daily summary:" (.getMessage e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/write-str {:error (.getMessage e)})})))

;; For local testing
(defn -main [& args]
  (println "Running test daily summary generation")
  (println "Result:" (handler {} nil)))
