(ns handler
  "API Lambda: List document counts by classification"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(def classifications
  [{:name "meeting"   :displayName "Meeting"   :icon "person.3"}
   {:name "idea"      :displayName "Idea"      :icon "lightbulb"}
   {:name "reference" :displayName "Reference" :icon "book"}
   {:name "journal"   :displayName "Journal"   :icon "book.closed"}
   {:name "project"   :displayName "Project"   :icon "folder"}])

(defn count-by-classification
  "Count documents for a specific classification using SELECT COUNT.
   This is more efficient than fetching all items and counting client-side."
  [classification]
  (ddb/query ddb-table
             :index-name "classification-index"
             :key-condition-expr "classification = :class"
             :expr-attr-values {":class" classification}
             :select "COUNT"))

(defn get-classification-counts
  "Get document counts for all classifications"
  []
  (mapv (fn [class-info]
          (assoc class-info :count (count-by-classification (:name class-info))))
        classifications))

(defn handler
  "Lambda handler for GET /classifications"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)

          _ (println "User" user-sub "listing classifications")

          classification-counts (get-classification-counts)]

      (r/ok {:classifications classification-counts}))

    (catch Exception e
      (println "Error listing classifications:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to list classifications"))))
