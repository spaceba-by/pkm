(ns handler
  "Lambda function: Execute web searches for due search monitors.
   Triggered by EventBridge on a fixed schedule (e.g., every 6 hours).
   Polls for active monitors whose next_execution has passed, executes
   Brave Search queries, stores snapshots in DynamoDB, and invokes
   the summarize Lambda asynchronously."
  (:require [aws.dynamodb :as ddb]
            [aws.brave-search :as brave]
            [aws.lambda :as lambda]
            [aws.secrets-manager :as sm]
            [search.provider :as sp]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.time Instant Duration]
           [java.time.temporal ChronoUnit]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def brave-search-secret-arn (System/getenv "BRAVE_SEARCH_SECRET_ARN"))
(def summarize-lambda (System/getenv "SUMMARIZE_LAMBDA_NAME"))

(defn- now-iso []
  (str (.truncatedTo (Instant/now) ChronoUnit/SECONDS)))

(defn- compute-next-execution
  "Compute next execution time from current time and interval in hours"
  [interval-hours]
  (let [next-time (.plus (Instant/now) (Duration/ofHours interval-hours))]
    (str (.truncatedTo next-time ChronoUnit/SECONDS))))

(defn get-due-monitors
  "Query the search-schedule-index GSI for active monitors whose next_execution <= now"
  [table-name]
  (let [now (now-iso)
        results (ddb/query table-name
                           :index-name "search-schedule-index"
                           :key-condition-expr "monitor_status = :status AND next_execution <= :now"
                           :expr-attr-values {":status" "active"
                                              ":now" now}
                           :limit 50)]
    ;; GSI projects ALL attributes, so results contain full items.
    ;; Filter any nil/incomplete items for safety (e.g., eventual consistency).
    (filterv #(and (some? %) (:monitor_id %)) results)))

(defn execute-search-terms
  "Execute web searches for all terms in a monitor. Returns a vector of
   {:term query :results [...]} maps."
  [provider terms]
  (mapv (fn [term]
          {:term term
           :results (try
                      (sp/search provider term {})
                      (catch Exception e
                        (println "Search failed for term:" term "-" (ex-message e))
                        []))})
        terms))

(defn store-snapshot
  "Store search snapshot in DynamoDB. Returns the snapshot SK for reference."
  [table-name user-pk monitor-id timestamp search-results]
  (let [sk (str "search_monitor#" monitor-id "#snapshot#" timestamp)
        item {:PK user-pk
              :SK sk
              :monitor_id monitor-id
              :timestamp timestamp
              :search_results search-results
              :result_count (reduce + (map #(count (:results %)) search-results))}]
    (ddb/put-item table-name item)
    sk))

(defn update-monitor-next-execution
  "Update the monitor's next_execution timestamp"
  [table-name user-pk monitor-sk interval-hours]
  (let [next-exec (compute-next-execution interval-hours)]
    (ddb/update-item table-name
                     {:PK user-pk :SK monitor-sk}
                     "SET next_execution = :ne, last_executed = :le"
                     {":ne" next-exec
                      ":le" (now-iso)})))

(defn process-monitor
  "Process a single monitor: execute searches, store snapshot, invoke summarizer"
  [provider table-name monitor]
  (let [user-pk (:PK monitor)
        monitor-sk (:SK monitor)
        monitor-id (:monitor_id monitor)
        terms (:search_terms monitor)
        interval-hours (or (:interval_hours monitor) 6)
        timestamp (now-iso)]

    (println "Processing monitor:" monitor-id "with" (count terms) "terms")

    ;; Execute searches
    (let [search-results (execute-search-terms provider terms)]
      ;; Store snapshot
      (let [snapshot-sk (store-snapshot table-name user-pk monitor-id timestamp search-results)]
        (println "Stored snapshot:" snapshot-sk "with"
                 (reduce + (map #(count (:results %)) search-results)) "results")

        ;; Update next execution time
        (update-monitor-next-execution table-name user-pk monitor-sk interval-hours)

        ;; Invoke summarize Lambda asynchronously
        (when summarize-lambda
          (lambda/invoke-async summarize-lambda
                              {:user_pk user-pk
                               :monitor_id monitor-id
                               :snapshot_timestamp timestamp
                               :monitor_name (:name monitor)
                               :novelty_threshold (or (:novelty_threshold monitor) 0.3)}))

        {:monitor-id monitor-id
         :terms-count (count terms)
         :results-count (reduce + (map #(count (:results %)) search-results))
         :snapshot-sk snapshot-sk}))))

(defn handler
  "Lambda handler for EventBridge scheduled invocation"
  [request]
  (try
    (let [_ (json/parse-string (:body request) true)]
      (println "Executing persistent search - checking for due monitors")

      ;; Retrieve API key from Secrets Manager
      (let [api-key (when-not (str/blank? brave-search-secret-arn)
                      (sm/get-secret-value brave-search-secret-arn))]
        (if (str/blank? api-key)
          (do
            (println "Brave Search API key not configured - skipping execution")
            {:statusCode 200
             :body (json/generate-string {:message "Brave Search API key not configured"
                                          :timestamp (now-iso)})})

          (let [due-monitors (get-due-monitors ddb-table)]
            (println "Found" (count due-monitors) "due monitors")

            (if (empty? due-monitors)
              {:statusCode 200
               :body (json/generate-string {:message "No monitors due for execution"
                                            :timestamp (now-iso)})}

              (let [provider (brave/create-provider api-key)
                results (mapv (fn [monitor]
                                (try
                                  (process-monitor provider ddb-table monitor)
                                  (catch Exception e
                                    (println "Error processing monitor:" (:monitor_id monitor)
                                             "-" (ex-message e))
                                    {:monitor-id (:monitor_id monitor)
                                     :error (ex-message e)})))
                              due-monitors)]
            {:statusCode 200
             :body (json/generate-string {:monitors-processed (count results)
                                          :results results
                                          :timestamp (now-iso)})})))))

    (catch Exception e
      (println "Error in persistent search execute:" (ex-message e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:error (ex-message e)})})))
