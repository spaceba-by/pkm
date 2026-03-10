(ns handler
  "API Lambda: Get unviewed insight count for badge display.
   Handles GET /insights/unviewed-count"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn- insight-pk [user-sub]
  (str "insight#" user-sub))

(defn get-unviewed-count
  "Count insight records where viewed_at is absent or modified_at > viewed_at"
  [user-sub]
  (let [items (ddb/query ddb-table
                         :key-condition-expr "PK = :pk"
                         :expr-attr-values {":pk" (insight-pk user-sub)})]
    (count (filter (fn [item]
                     (let [viewed-at (:viewed_at item)
                           modified-at (:modified_at item)]
                       (or (nil? viewed-at)
                           (pos? (compare modified-at viewed-at)))))
                   items))))

(defn handler
  "Lambda handler for GET /insights/unviewed-count"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)
          _ (println "User" user-sub "getting unviewed count")
          count (get-unviewed-count user-sub)]
      (r/ok-no-cache {:unviewedCount count}))

    (catch Exception e
      (println "Error getting unviewed count:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to get unviewed count"))))
