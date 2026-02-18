(ns handler
  "API Lambda: Get search monitor details with recent summaries.
   Handles GET /searches/{id}"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn- user-pk [user-sub]
  (str "user#" user-sub))

(defn- monitor-sk [monitor-id]
  (str "search_monitor#" monitor-id "#CONFIG"))

(defn- format-monitor
  "Format a monitor record for API response"
  [monitor]
  {:id (:monitor_id monitor)
   :name (:name monitor)
   :description (:description monitor)
   :searchTerms (:search_terms monitor)
   :intervalHours (:interval_hours monitor)
   :noveltyThreshold (:novelty_threshold monitor)
   :status (:monitor_status monitor)
   :lastExecuted (:last_executed monitor)
   :nextExecution (:next_execution monitor)
   :created (:created monitor)
   :modified (:modified monitor)})

(defn- format-summary
  "Format a summary record for API response"
  [summary]
  {:timestamp (:timestamp summary)
   :summary (:summary_text summary)
   :topics (or (:topics summary) [])
   :noveltyScore (:novelty_score summary)
   :significantUpdate (:significant_update summary)
   :newItems (or (:new_items summary) [])
   :changedItems (or (:changed_items summary) [])
   :removedItems (or (:removed_items summary) [])
   :analysis (:analysis summary)})

(defn handler
  "Lambda handler for GET /searches/{id}"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)
          path-params (r/parse-path-params event)
          monitor-id (or (:id path-params) (get path-params "id"))
          query-params (r/parse-query-params event)
          summary-limit (r/parse-int-param query-params "limit" 10)]

      (println "User" user-sub "getting monitor detail:" monitor-id)

      (if (str/blank? monitor-id)
        (r/bad-request "Monitor ID is required")

        (let [pk (user-pk user-sub)
              monitor (ddb/get-item ddb-table {:PK pk :SK (monitor-sk monitor-id)})]

          (if (nil? monitor)
            (r/not-found (str "Monitor not found: " monitor-id))

            ;; Fetch recent summaries
            (let [summaries (ddb/query ddb-table
                                       :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                                       :expr-attr-values {":pk" pk
                                                           ":prefix" (str "search_monitor#" monitor-id "#summary#")}
                                       :limit 100)
                  ;; Sort by timestamp descending and take limit
                  sorted-summaries (->> summaries
                                        (sort-by :timestamp #(compare %2 %1))
                                        (take summary-limit)
                                        (mapv format-summary))]

              (r/ok {:monitor (format-monitor monitor)
                     :summaries sorted-summaries
                     :summaryCount (count sorted-summaries)}))))))

    (catch Exception e
      (println "Error in search monitor detail API:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to get monitor details"))))
