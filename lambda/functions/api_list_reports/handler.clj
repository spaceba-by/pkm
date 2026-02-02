(ns handler
  "API Lambda: List weekly reports from _agent directory"
  (:require [aws.s3 :as s3]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def reports-prefix "_agent/reports/weekly/")
(def default-limit 12)
(def max-limit 52)

(defn list-report-files
  "List weekly report files from S3.
   Note: S3 list-objects has a 1000 object limit per request. This is acceptable
   for weekly reports as it would take 19+ years to exceed this limit.
   If pagination is needed in the future, implement continuation tokens."
  []
  (try
    (s3/list-objects s3-bucket reports-prefix)
    (catch Exception e
      (println "Error listing reports:" (.getMessage e))
      [])))

(defn parse-report-key
  "Extract week date from report file path"
  [key]
  (when (and key (str/ends-with? key ".md"))
    (let [filename (last (str/split key #"/"))
          week-date (str/replace filename ".md" "")]
      {:id key
       :weekOf week-date})))

(defn list-reports
  "List weekly report files, sorted by date descending"
  [limit]
  (let [objects (list-report-files)]
    (->> objects
         (filter #(str/ends-with? (str %) ".md"))
         (map parse-report-key)
         (filter some?)
         (sort-by :weekOf #(compare %2 %1))  ; Most recent first
         (take (min limit max-limit))
         (vec))))

(defn handler
  "Lambda handler for GET /reports"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          params (r/parse-query-params event)
          limit (r/parse-int-param params "limit" default-limit)
          user-sub (r/get-user-sub event)

          _ (println "User" user-sub "listing reports, limit:" limit)

          reports (list-reports limit)]

      (r/ok {:reports reports
             :count (count reports)}))

    (catch Exception e
      (println "Error listing reports:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to list reports"))))
