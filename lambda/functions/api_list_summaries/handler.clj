(ns handler
  "API Lambda: List daily summaries from _agent directory"
  (:require [aws.s3 :as s3]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def summaries-prefix "_agent/summaries/")
(def default-limit 30)
(def max-limit 100)

(defn list-summary-files
  "List daily summary files from S3.
   Note: S3 list-objects has a 1000 object limit per request. This is acceptable
   for daily summaries as it would take 2.7+ years to exceed this limit.
   If pagination is needed in the future, implement continuation tokens."
  []
  (try
    (s3/list-objects s3-bucket summaries-prefix)
    (catch Exception e
      (println "Error listing summaries:" (ex-message e))
      [])))

(defn parse-summary-key
  "Extract date from summary file path"
  [key]
  (when (and key (str/ends-with? key ".md"))
    (let [filename (last (str/split key #"/"))
          date (str/replace filename ".md" "")]
      {:id key
       :date date})))

(defn list-summaries
  "List daily summary files, sorted by date descending"
  [limit]
  (let [objects (list-summary-files)]
    (->> objects
         (filter #(str/ends-with? (str %) ".md"))
         (map parse-summary-key)
         (filter some?)
         (sort-by :date #(compare %2 %1))  ; Most recent first
         (take (min limit max-limit))
         (vec))))

(defn handler
  "Lambda handler for GET /summaries"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          params (r/parse-query-params event)
          limit (r/parse-int-param params "limit" default-limit)
          user-sub (r/get-user-sub event)

          _ (println "User" user-sub "listing summaries, limit:" limit)

          summaries (list-summaries limit)]

      (r/ok {:summaries summaries
             :count (count summaries)}))

    (catch Exception e
      (println "Error listing summaries:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to list summaries"))))
