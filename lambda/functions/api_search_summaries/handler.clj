(ns handler
  "API Lambda: List and get summaries for a search monitor.
   Handles GET /searches/{id}/summaries and GET /searches/{id}/summaries/{timestamp}"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn- user-pk [user-sub]
  (str "user#" user-sub))

(defn- format-summary
  "Format a summary record for API response"
  [summary viewed-set]
  {:timestamp (:timestamp summary)
   :summary (:summary_text summary)
   :topics (or (:topics summary) [])
   :noveltyScore (:novelty_score summary)
   :significantUpdate (:significant_update summary)
   :newItems (or (:new_items summary) [])
   :changedItems (or (:changed_items summary) [])
   :removedItems (or (:removed_items summary) [])
   :analysis (:analysis summary)
   :viewed (boolean (get viewed-set (:timestamp summary)))})

(defn list-summaries
  "List summaries for a monitor"
  [user-sub monitor-id limit]
  (let [pk (user-pk user-sub)
        results (ddb/query-all ddb-table
                               :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                               :expr-attr-values {":pk" pk
                                                   ":prefix" (str "search_monitor#" monitor-id "#summary#")})
        ;; Build set of viewed timestamps from insight records
        insight-items (ddb/query-all ddb-table
                                      :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                                      :expr-attr-values {":pk" "insight"
                                                          ":prefix" (str "search#" monitor-id "#")})
        viewed-set (into #{}
                         (comp
                          (filter (fn [item]
                                    (let [viewed-at (:viewed_at item)
                                          modified-at (:modified_at item)]
                                      (and (some? viewed-at)
                                           (not (pos? (compare modified-at viewed-at)))))))
                          (map (fn [item]
                                 (subs (:SK item) (+ (count "search#") (count monitor-id) 1)))))
                         insight-items)
        sorted (->> results
                    (sort-by :timestamp #(compare %2 %1))
                    (take limit)
                    (mapv #(format-summary % viewed-set)))]
    (r/ok {:summaries sorted
           :count (count sorted)
           :monitorId monitor-id})))

(defn get-summary
  "Get a specific summary by timestamp"
  [user-sub monitor-id timestamp]
  (let [pk (user-pk user-sub)
        sk (str "search_monitor#" monitor-id "#summary#" timestamp)
        item (ddb/get-item ddb-table {:PK pk :SK sk})]
    (if (nil? item)
      (r/not-found (str "Summary not found for timestamp: " timestamp))
      (let [insight-sk (str "search#" monitor-id "#" timestamp)
            insight (ddb/get-item ddb-table {:PK "insight" :SK insight-sk})
            viewed? (and (some? (:viewed_at insight))
                         (not (pos? (compare (:modified_at insight) (:viewed_at insight)))))]
        (r/ok (format-summary item (if viewed? #{timestamp} #{})))))))

(defn handler
  "Lambda handler for search summaries API"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)
          path-params (r/parse-path-params event)
          monitor-id (or (:id path-params) (get path-params "id"))
          timestamp (or (:timestamp path-params) (get path-params "timestamp"))
          query-params (r/parse-query-params event)
          limit (r/parse-int-param query-params "limit" 20)]

      (println "User" user-sub "summaries for monitor:" monitor-id "timestamp:" timestamp)

      (cond
        (str/blank? monitor-id)
        (r/bad-request "Monitor ID is required")

        timestamp
        (get-summary user-sub monitor-id timestamp)

        :else
        (list-summaries user-sub monitor-id limit)))

    (catch Exception e
      (println "Error in search summaries API:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to get summaries"))))
