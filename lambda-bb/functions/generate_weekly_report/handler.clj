(ns generate-weekly-report.handler
  "Lambda function to generate weekly reports of PKM activity"
  (:require [aws.s3 :as s3]
            [aws.dynamodb :as ddb]
            [aws.bedrock :as bedrock]
            [markdown.utils :as md]
            [clojure.data.json :as json]
            [java-time.api :as time]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def bedrock-model (System/getenv "BEDROCK_MODEL_ID"))

(defn get-target-date
  "Get target date from event or default to last week"
  [event]
  (if-let [date-str (:date event)]
    (time/instant date-str)
    ;; Default to last week (report runs on Sunday for previous week)
    (time/minus (time/instant) (time/days 7))))

(defn calculate-week-boundaries
  "Calculate week start (Monday) and end (Sunday) for given date"
  [target-date]
  (let [week-start (time/adjust target-date :previous-or-same-day-of-week :monday)
        week-end (time/plus week-start (time/days 7))]
    {:start week-start
     :end week-end}))

(defn filter-week-docs
  "Filter documents to those within target week"
  [docs week-start-iso week-end-iso]
  (filter (fn [doc]
            (let [modified (or (:modified doc) "")]
              (and (>= (compare modified week-start-iso) 0)
                   (< (compare modified week-end-iso) 0))))
          docs))

(defn retrieve-daily-summaries
  "Retrieve daily summaries for the week"
  [week-start]
  (println "Retrieving daily summaries for the week")
  (let [summaries (atom [])]
    (doseq [i (range 7)]
      (let [day (time/plus week-start (time/days i))
            day-str (time/format "yyyy-MM-dd" day)
            summary (s3/get-daily-summary s3-bucket day-str)]
        (when summary
          (swap! summaries conj {:date day-str
                                :content summary}))))
    (println "Found" (count @summaries) "daily summaries")
    @summaries))

(defn compile-week-data
  "Compile week data for AI analysis"
  [week-str week-start week-end week-docs daily-summaries]
  (let [;; Calculate classification counts
        classification-counts (frequencies (map #(get % :classification "unknown") week-docs))

        ;; Sample documents (up to 30)
        sample-docs (take 30
                         (remove #(.startsWith (:pk %) "_agent/") week-docs))

        documents (mapv (fn [doc]
                         {:path (:pk doc)
                          :title (or (:title doc) "Untitled")
                          :classification (or (:classification doc) "unknown")
                          :tags (or (:tags doc) [])})
                       sample-docs)]

    {:week week-str
     :start_date (time/format "yyyy-MM-dd" week-start)
     :end_date (time/format "yyyy-MM-dd" (time/minus week-end (time/days 1)))
     :document_count (count week-docs)
     :daily_summaries daily-summaries
     :documents documents
     :classification_counts classification-counts}))

(defn handler
  "Lambda handler for Step Functions or scheduled EventBridge event"
  [event context]
  (try
    (println "Generating weekly report")

    ;; Get target date
    (let [target-date (get-target-date event)
          week-str (md/get-week-string target-date)
          _ (println "Target week:" week-str)

          ;; Calculate week boundaries
          {:keys [start end]} (calculate-week-boundaries target-date)
          week-start start
          week-end end
          _ (println "Week range:" (str week-start) "to" (str week-end))

          ;; Query documents modified during the week
          week-start-iso (str week-start)
          week-end-iso (str week-end)
          _ (println "Querying documents modified since" week-start-iso)

          week-docs-all (ddb/get-documents-modified-since ddb-table week-start-iso :limit 2000)

          ;; Filter to target week
          week-docs (filter-week-docs week-docs-all week-start-iso week-end-iso)
          _ (println "Found" (count week-docs) "documents for" week-str)

          ;; Retrieve daily summaries
          daily-summaries (retrieve-daily-summaries week-start)

          ;; Compile week data
          week-data (compile-week-data week-str week-start week-end week-docs daily-summaries)

          _ (println "Generating report with" (count (:documents week-data)) "documents")

          ;; Generate report using Bedrock
          report-content (bedrock/generate-weekly-report bedrock-model week-data)

          ;; Create report document
          report-doc (md/create-weekly-report-document week-str
                                                       report-content
                                                       (count week-docs))

          ;; Upload report to S3
          report-key (s3/put-agent-output s3-bucket
                                         "reports/weekly"
                                         (str week-str ".md")
                                         report-doc)]

      (println "Created weekly report:" report-key)

      {:statusCode 200
       :body (json/write-str {:week week-str
                              :report-key report-key
                              :document-count (count week-docs)
                              :daily-summaries-count (count daily-summaries)})})

    (catch Exception e
      (println "Error generating weekly report:" (.getMessage e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/write-str {:error (.getMessage e)})})))

;; For local testing
(defn -main [& args]
  (println "Running test weekly report generation")
  (println "Result:" (handler {} nil)))
