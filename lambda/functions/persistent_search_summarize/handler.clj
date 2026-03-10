(ns handler
  "Lambda function: Summarize search results and compute novelty score.
   Invoked asynchronously by persistent_search_execute.
   Retrieves the latest snapshot and previous summary, generates a new
   summary via Bedrock, computes a novelty score, and writes flagged
   results to S3 for vault sync."
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [search.summarizer :as summarizer]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.time Instant LocalDate ZoneOffset]
           [java.time.format DateTimeFormatter]
           [java.time.temporal ChronoUnit]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def bedrock-model (System/getenv "BEDROCK_MODEL_ID"))

(defn- now-iso []
  (str (.truncatedTo (Instant/now) ChronoUnit/SECONDS)))

(defn- today-str []
  (.format (LocalDate/now ZoneOffset/UTC) (DateTimeFormatter/ofPattern "yyyy-MM-dd")))

(defn get-snapshot
  "Retrieve a search snapshot by monitor-id and timestamp"
  [table-name user-pk monitor-id timestamp]
  (ddb/get-item table-name
                {:PK user-pk
                 :SK (str "search_monitor#" monitor-id "#snapshot#" timestamp)}))

(defn get-previous-summary
  "Get the most recent summary for a monitor (before the current one).
   Returns the summary text or nil if no previous summary exists."
  [table-name user-pk monitor-id]
  (let [results (ddb/query table-name
                           :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                           :expr-attr-values {":pk" user-pk
                                              ":prefix" (str "search_monitor#" monitor-id "#summary#")}
                           :scan-index-forward false
                           :limit 1)]
    (when (seq results)
      (:summary_text (first results)))))

(defn store-summary
  "Store a search summary in DynamoDB"
  [table-name user-pk monitor-id timestamp summary-data]
  (let [sk (str "search_monitor#" monitor-id "#summary#" timestamp)]
    (ddb/put-item table-name
                  (merge {:PK user-pk
                          :SK sk
                          :monitor_id monitor-id
                          :timestamp timestamp}
                         summary-data))
    sk))

(defn store-notification
  "Store a notification event record in DynamoDB for future consumption"
  [table-name user-pk monitor-id monitor-name novelty-score timestamp]
  (let [notification-id (str (java.util.UUID/randomUUID))
        sk (str "notification#pending#" timestamp "#" notification-id)]
    (ddb/put-item table-name
                  {:PK user-pk
                   :SK sk
                   :notification_id notification-id
                   :notification_type "search_monitor"
                   :monitor_id monitor-id
                   :monitor_name monitor-name
                   :novelty_score novelty-score
                   :timestamp timestamp
                   :read false})
    sk))

(defn write-search-report
  "Write a search report to S3 for vault sync"
  [bucket monitor-id monitor-name summary-text topics diff timestamp]
  (let [report (summarizer/format-search-report monitor-name summary-text topics diff timestamp)
        date-str (today-str)
        filename (str date-str ".md")]
    (s3/put-agent-output bucket (str "searches/" monitor-id) filename report)))

(defn handler
  "Lambda handler for async invocation from persistent_search_execute"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-pk (:user_pk event)
          monitor-id (:monitor_id event)
          snapshot-timestamp (:snapshot_timestamp event)
          monitor-name (or (:monitor_name event) monitor-id)
          novelty-threshold (or (:novelty_threshold event) 0.3)]

      (println "Summarizing search results for monitor:" monitor-id
               "snapshot:" snapshot-timestamp)

      ;; Retrieve the snapshot
      (let [snapshot (get-snapshot ddb-table user-pk monitor-id snapshot-timestamp)]
        (if (nil? snapshot)
          (do
            (println "Snapshot not found for monitor:" monitor-id "at:" snapshot-timestamp)
            {:statusCode 404
             :body (json/generate-string {:error "Snapshot not found"})})

          (let [search-results (:search_results snapshot)
                _ (println "Processing" (count search-results) "search term results")

                ;; Get previous summary for comparison
                previous-summary (get-previous-summary ddb-table user-pk monitor-id)
                _ (println "Previous summary:" (if previous-summary "found" "none"))

                ;; Generate new summary
                summary-result (summarizer/summarize-results bedrock-model search-results)
                summary-text (:summary summary-result)
                topics (or (:topics summary-result) [])

                ;; Compare with previous summary
                diff (summarizer/compare-summaries bedrock-model summary-text previous-summary)
                novelty-score (:novelty_score diff)
                significant? (> novelty-score novelty-threshold)

                _ (println "Novelty score:" novelty-score
                           "threshold:" novelty-threshold
                           "significant:" significant?)

                ;; Store summary in DynamoDB
                summary-sk (store-summary ddb-table user-pk monitor-id snapshot-timestamp
                                          {:summary_text summary-text
                                           :topics topics
                                           :novelty_score novelty-score
                                           :significant_update significant?
                                           :new_items (or (:new_items diff) [])
                                           :changed_items (or (:changed_items diff) [])
                                           :removed_items (or (:removed_items diff) [])
                                           :analysis (:analysis diff)})]

            ;; If significant, write to S3, create insight record, and create notification
            (when significant?
              (println "Significant update detected - writing to S3 and creating notification")
              (write-search-report s3-bucket monitor-id monitor-name
                                   summary-text topics diff snapshot-timestamp)

              ;; Write per-user insight record for viewed-status tracking
              (ddb/put-item ddb-table
                            {:PK (str "insight#" (subs user-pk (count "user#")))
                             :SK (str "search#" monitor-id "#" snapshot-timestamp)
                             :type "search_monitor"
                             :monitor_id monitor-id
                             :monitor_name monitor-name
                             :novelty_score novelty-score
                             :modified_at snapshot-timestamp
                             :s3_key (str "_agent/searches/" monitor-id "/" (today-str) ".md")})

              (store-notification ddb-table user-pk monitor-id monitor-name
                                 novelty-score snapshot-timestamp))

            {:statusCode 200
             :body (json/generate-string {:monitor-id monitor-id
                                          :novelty-score novelty-score
                                          :significant significant?
                                          :summary-sk summary-sk})}))))

    (catch Exception e
      (println "Error in persistent search summarize:" (ex-message e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:error (ex-message e)})})))
