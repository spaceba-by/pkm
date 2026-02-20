(ns handler
  "API Lambda: List all unique tags with document counts"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn get-all-tags
  "Get all unique tags with document counts from document metadata.
   Uses scan-all to paginate through the entire table, ensuring all
   METADATA items are retrieved regardless of table size."
  []
  ;; Scan all metadata items with pagination and extract tags
  (let [all-docs (ddb/scan-all ddb-table
                               :filter-expr "SK = :sk"
                               :expr-attr-values {":sk" "METADATA"})
        ;; Flatten all tags from all documents
        all-tags (mapcat #(or (:tags %) []) all-docs)
        ;; Count occurrences of each tag
        tag-counts (frequencies all-tags)]
    (->> tag-counts
         (map (fn [[tag-name count]]
                {:name tag-name
                 :count count}))
         (sort-by :name)
         (vec))))

(defn handler
  "Lambda handler for GET /tags"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)

          _ (println "User" user-sub "listing tags")

          tags (get-all-tags)]

      (r/ok {:tags tags
             :count (count tags)}))

    (catch Exception e
      (println "Error listing tags:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to list tags"))))
