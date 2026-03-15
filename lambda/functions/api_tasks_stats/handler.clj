(ns handler
  "API Lambda: Get task statistics (counts by status)"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn handler
  "Lambda handler for task stats API"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)]

      (println "User" user-sub "requesting task stats")

      ;; Count open and completed tasks using GSI with SELECT COUNT
      (let [open-count (ddb/query ddb-table
                                   :key-condition-expr "PK = :pk"
                                   :expr-attr-values {":pk" "task#open"}
                                   :select "COUNT")
            completed-count (ddb/query ddb-table
                                        :key-condition-expr "PK = :pk"
                                        :expr-attr-values {":pk" "task#completed"}
                                        :select "COUNT")]
        (r/ok {:open open-count
               :completed completed-count
               :total (+ open-count completed-count)})))

    (catch Exception e
      (println "Error getting task stats:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to get task stats"))))
