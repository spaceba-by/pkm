(ns handler
  "API Lambda: List weekly reports with viewed status.
   Queries DynamoDB insight records first, falls back to S3 listing."
  (:require [aws.s3 :as s3]
            [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def reports-prefix "_agent/reports/weekly/")
(def default-limit 12)
(def max-limit 52)

(defn- is-viewed?
  "Check if an insight record has been viewed (viewed_at >= modified_at)"
  [item]
  (let [viewed-at (:viewed_at item)
        modified-at (:modified_at item)]
    (and (some? viewed-at)
         (not (pos? (compare modified-at viewed-at))))))

(defn- insight-pk [user-sub]
  (str "insight#" user-sub))

(defn- list-from-dynamodb
  "List reports from DynamoDB insight records with viewed status"
  [user-sub limit]
  (let [items (ddb/query ddb-table
                         :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                         :expr-attr-values {":pk" (insight-pk user-sub)
                                             ":prefix" "report#"}
                         :scan-index-forward false)]
    (->> items
         (map (fn [item]
                {:id (:s3_key item)
                 :weekOf (subs (:SK item) (count "report#"))
                 :viewed (is-viewed? item)}))
         (sort-by :weekOf #(compare %2 %1))
         (take (min limit max-limit))
         (vec))))

(defn- list-from-s3
  "Fallback: list reports from S3 (pre-migration, all treated as viewed)"
  [limit]
  (let [objects (try
                  (s3/list-objects s3-bucket reports-prefix)
                  (catch Exception e
                    (println "Error listing reports from S3:" (ex-message e))
                    []))]
    (->> objects
         (filter #(str/ends-with? (str %) ".md"))
         (map (fn [key]
                (let [filename (last (str/split key #"/"))
                      week-date (str/replace filename ".md" "")]
                  {:id key :weekOf week-date :viewed true})))
         (filter #(some? (:weekOf %)))
         (sort-by :weekOf #(compare %2 %1))
         (take (min limit max-limit))
         (vec))))

(defn list-reports
  "List weekly reports, preferring DynamoDB records, falling back to S3"
  [user-sub limit]
  (let [ddb-results (list-from-dynamodb user-sub limit)]
    (if (seq ddb-results)
      ddb-results
      (list-from-s3 limit))))

(defn handler
  "Lambda handler for GET /reports"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          params (r/parse-query-params event)
          limit (r/parse-int-param params "limit" default-limit)
          user-sub (r/get-user-sub event)

          _ (println "User" user-sub "listing reports, limit:" limit)

          reports (list-reports user-sub limit)]

      (r/ok {:reports reports
             :count (count reports)}))

    (catch Exception e
      (println "Error listing reports:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to list reports"))))
