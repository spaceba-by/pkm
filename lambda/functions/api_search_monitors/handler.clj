(ns handler
  "API Lambda: CRUD operations for search monitors.
   Handles POST /searches, GET /searches, PUT /searches/{id}, DELETE /searches/{id}"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.time Instant Duration]
           [java.time.temporal ChronoUnit]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(def valid-statuses #{"active" "paused"})
(def min-interval-hours 1)
(def max-interval-hours 168) ;; 1 week

(defn- now-iso []
  (str (.truncatedTo (Instant/now) ChronoUnit/SECONDS)))

(defn- compute-next-execution [interval-hours]
  (let [next-time (.plus (Instant/now) (Duration/ofHours interval-hours))]
    (str (.truncatedTo next-time ChronoUnit/SECONDS))))

(defn- monitor-sk [monitor-id]
  (str "search_monitor#" monitor-id "#CONFIG"))

(defn- user-pk [user-sub]
  (str "user#" user-sub))

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

(defn create-monitor
  "Create a new search monitor"
  [user-sub body]
  (let [monitor-id (str (java.util.UUID/randomUUID))
        name (get body :name)
        description (get body :description "")
        search-terms (get body :searchTerms [])
        interval-hours (or (get body :intervalHours) 6)
        novelty-threshold (or (get body :noveltyThreshold) 0.3)
        now (now-iso)
        pk (user-pk user-sub)
        sk (monitor-sk monitor-id)]

    (cond
      (str/blank? name)
      (r/bad-request "Monitor name is required")

      (empty? search-terms)
      (r/bad-request "At least one search term is required")

      (or (< interval-hours min-interval-hours)
          (> interval-hours max-interval-hours))
      (r/bad-request (str "Interval must be between " min-interval-hours " and " max-interval-hours " hours"))

      (or (< novelty-threshold 0.0) (> novelty-threshold 1.0))
      (r/bad-request "Novelty threshold must be between 0.0 and 1.0")

      :else
      (let [item {:PK pk
                  :SK sk
                  :monitor_id monitor-id
                  :name name
                  :description description
                  :search_terms search-terms
                  :interval_hours interval-hours
                  :novelty_threshold novelty-threshold
                  :monitor_status "active"
                  :next_execution (compute-next-execution interval-hours)
                  :created now
                  :modified now}]
        (ddb/put-item ddb-table item)
        (r/ok-no-cache (format-monitor item))))))

(defn list-monitors
  "List all search monitors for the user"
  [user-sub]
  (let [pk (user-pk user-sub)
        results (ddb/query-all ddb-table
                               :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                               :expr-attr-values {":pk" pk
                                                   ":prefix" "search_monitor#"})
        ;; Filter to CONFIG items only (not snapshots or summaries)
        configs (filter #(str/ends-with? (:SK %) "#CONFIG") results)]
    (r/ok {:monitors (mapv format-monitor configs)
           :count (count configs)})))

(defn update-monitor
  "Update an existing search monitor"
  [user-sub monitor-id body]
  (let [pk (user-pk user-sub)
        sk (monitor-sk monitor-id)
        existing (ddb/get-item ddb-table {:PK pk :SK sk})]

    (if (nil? existing)
      (r/not-found (str "Monitor not found: " monitor-id))

      (let [now (now-iso)
            updates (cond-> {:modified now}
                      (:name body) (assoc :name (:name body))
                      (:description body) (assoc :description (:description body))
                      (:searchTerms body) (assoc :search_terms (:searchTerms body))
                      (:intervalHours body) (assoc :interval_hours (:intervalHours body))
                      (:noveltyThreshold body) (assoc :novelty_threshold (:noveltyThreshold body))
                      (:status body) (assoc :monitor_status (:status body)))

            ;; Recalculate next execution if interval changed or status changed to active
            updates (if (or (:intervalHours body)
                            (= "active" (:status body)))
                      (assoc updates :next_execution
                             (compute-next-execution (or (:intervalHours body)
                                                         (:interval_hours existing))))
                      updates)]

        ;; Validate updates
        (cond
          (and (contains? body :name) (str/blank? (:name body)))
          (r/bad-request "Monitor name cannot be blank")

          (and (:searchTerms body) (empty? (:searchTerms body)))
          (r/bad-request "At least one search term is required")

          (and (:intervalHours body)
               (or (< (:intervalHours body) min-interval-hours)
                   (> (:intervalHours body) max-interval-hours)))
          (r/bad-request (str "Interval must be between " min-interval-hours " and " max-interval-hours " hours"))

          (and (:noveltyThreshold body)
               (or (< (:noveltyThreshold body) 0.0) (> (:noveltyThreshold body) 1.0)))
          (r/bad-request "Novelty threshold must be between 0.0 and 1.0")

          (and (:status body) (not (valid-statuses (:status body))))
          (r/bad-request (str "Status must be one of: " (str/join ", " (sort valid-statuses))))

          :else
          (let [updated (ddb/update-item-attrs ddb-table {:PK pk :SK sk} updates)]
            (r/ok-no-cache (format-monitor updated))))))))

(defn delete-monitor
  "Delete a search monitor and its history"
  [user-sub monitor-id]
  (let [pk (user-pk user-sub)
        sk (monitor-sk monitor-id)
        existing (ddb/get-item ddb-table {:PK pk :SK sk})]

    (if (nil? existing)
      (r/not-found (str "Monitor not found: " monitor-id))

      (do
        ;; Delete config
        (ddb/delete-item ddb-table {:PK pk :SK sk})

        ;; Delete snapshots and summaries for this monitor
        (let [related (ddb/query-all ddb-table
                                     :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                                     :expr-attr-values {":pk" pk
                                                         ":prefix" (str "search_monitor#" monitor-id "#")})]
          (doseq [item related]
            (ddb/delete-item ddb-table {:PK (:PK item) :SK (:SK item)})))

        (r/ok-no-cache {:deleted true :id monitor-id})))))

(defn handler
  "Lambda handler for search monitor CRUD operations"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)
          http-method (or (get-in event [:requestContext :http :method])
                          (get-in event ["requestContext" "http" "method"]))
          path-params (r/parse-path-params event)
          monitor-id (or (:id path-params) (get path-params "id"))

          request-body (when-let [body (or (:body event) (get event "body"))]
                         (if (string? body)
                           (json/parse-string body true)
                           body))]

      (println "User" user-sub "method:" http-method "monitor-id:" monitor-id)

      (case http-method
        "POST" (create-monitor user-sub request-body)
        "GET" (list-monitors user-sub)
        "PUT" (if monitor-id
                (update-monitor user-sub monitor-id request-body)
                (r/bad-request "Monitor ID required"))
        "DELETE" (if monitor-id
                   (delete-monitor user-sub monitor-id)
                   (r/bad-request "Monitor ID required"))
        (r/bad-request (str "Unsupported method: " http-method))))

    (catch Exception e
      (println "Error in search monitors API:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to process search monitor request"))))
