(ns handler
  "API Lambda: Mark insights as viewed.
   Handles PUT /summaries/{date}/viewed, PUT /reports/{week}/viewed,
   PUT /searches/{id}/summaries/{timestamp}/viewed, and PUT /insights/mark-all-viewed"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.time Instant]
           [java.time.temporal ChronoUnit]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn- now-iso []
  (str (.truncatedTo (Instant/now) ChronoUnit/SECONDS)))

(defn- insight-pk [user-sub]
  (str "insight#" user-sub))

(defn- mark-insight-viewed
  "Set viewed_at on an insight record"
  [user-sub sk]
  (let [pk (insight-pk user-sub)
        item (ddb/get-item ddb-table {:PK pk :SK sk})]
    (if (nil? item)
      (r/not-found (str "Insight not found: " sk))
      (do
        (ddb/update-item-attrs ddb-table
                               {:PK pk :SK sk}
                               {:viewed_at (now-iso)})
        (r/ok-no-cache {:sk sk :viewed true})))))

(defn- mark-all-viewed
  "Set viewed_at on all unviewed insight records for the authenticated user"
  [user-sub]
  (let [pk (insight-pk user-sub)
        items (ddb/query ddb-table
                         :key-condition-expr "PK = :pk"
                         :expr-attr-values {":pk" pk})
        now-ts (now-iso)
        unviewed (filter (fn [item]
                           (let [viewed-at (:viewed_at item)
                                 modified-at (:modified_at item)]
                             (or (nil? viewed-at)
                                 (pos? (compare modified-at viewed-at)))))
                         items)]
    (doseq [item unviewed]
      (ddb/update-item-attrs ddb-table
                             {:PK pk :SK (:SK item)}
                             {:viewed_at now-ts}))
    (r/ok-no-cache {:marked (count unviewed)})))

(defn handler
  "Lambda handler for mark-viewed operations"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)
          path-params (r/parse-path-params event)
          raw-path (or (get-in event [:requestContext :http :path])
                       (get-in event ["requestContext" "http" "path"])
                       "")]

      (println "User" user-sub "mark-viewed path:" raw-path)

      (cond
        ;; PUT /insights/mark-all-viewed
        (str/ends-with? raw-path "/mark-all-viewed")
        (mark-all-viewed user-sub)

        ;; PUT /searches/{id}/summaries/{timestamp}/viewed
        ;; (must match before /summaries/ to avoid false match)
        (str/includes? raw-path "/searches/")
        (let [monitor-id (or (:id path-params) (get path-params "id"))
              timestamp (or (:timestamp path-params) (get path-params "timestamp"))]
          (if (or (str/blank? monitor-id) (str/blank? timestamp))
            (r/bad-request "Monitor ID and timestamp required")
            (mark-insight-viewed user-sub (str "search#" monitor-id "#" timestamp))))

        ;; PUT /summaries/{date}/viewed
        (str/includes? raw-path "/summaries/")
        (let [date (or (:date path-params) (get path-params "date"))]
          (if (str/blank? date)
            (r/bad-request "Date parameter required")
            (mark-insight-viewed user-sub (str "summary#" date))))

        ;; PUT /reports/{week}/viewed
        (str/includes? raw-path "/reports/")
        (let [week (or (:week path-params) (get path-params "week"))]
          (if (str/blank? week)
            (r/bad-request "Week parameter required")
            (mark-insight-viewed user-sub (str "report#" week))))

        :else
        (r/bad-request "Unsupported path")))

    (catch Exception e
      (println "Error in mark-viewed API:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to mark as viewed"))))
