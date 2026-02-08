(ns handler
  "API Lambda: Search documents by query"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def default-limit 20)
(def max-limit 50)

(defn get-all-documents
  "Get all document metadata for client-side search"
  []
  (ddb/scan ddb-table
            :filter-expr "SK = :sk"
            :expr-attr-values {":sk" "METADATA"}
            :limit 500))

(defn matches-query?
  "Check if document matches search query (case-insensitive)"
  [doc query-lower]
  (let [title (str/lower-case (or (:title doc) ""))
        tags (or (:tags doc) [])
        pk (str/lower-case (or (:PK doc) ""))]
    (or (str/includes? title query-lower)
        (str/includes? pk query-lower)
        (some #(str/includes? (str/lower-case %) query-lower) tags))))

(defn search-documents
  "Search documents by title, path, and tags.
   Note: This is a temporary client-side filtering implementation that fetches
   up to 500 documents and filters in memory. This approach is acceptable for
   small-to-medium PKM vaults but has O(n) performance.
   TODO: For production-scale search, implement OpenSearch/Elasticsearch
   integration for full-text search with relevance scoring."
  [query limit]
  (let [query-lower (str/lower-case query)
        all-docs (get-all-documents)]
    (->> all-docs
         (filter #(matches-query? % query-lower))
         (take limit)
         (vec))))

(def default-timestamp "1970-01-01T00:00:00Z")

(defn format-search-result
  "Format document for search results.
   Returns nested metadata structure matching iOS Document model.
   Defaults non-optional fields to prevent iOS decoding failures."
  [doc]
  (let [modified (or (:modified doc) default-timestamp)
        created (or (:created doc) modified)]
    {:id (:PK doc)
     :title (or (:title doc) "Untitled")
     :metadata {:classification (or (:classification doc) "reference")
                :tags (or (:tags doc) [])
                :linksTo (or (:links_to doc) [])
                :entities (:entities doc)
                :created created
                :modified modified
                :hasFrontmatter (if (some? (:has_frontmatter doc))
                                  (:has_frontmatter doc)
                                  false)}}))

(defn handler
  "Lambda handler for GET /search?q=..."
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          params (r/parse-query-params event)
          query (or (get params :q) (get params "q"))
          limit (r/parse-int-param params "limit" default-limit)
          user-sub (r/get-user-sub event)]

      (when (or (nil? query) (str/blank? query))
        (throw (ex-info "Query parameter 'q' is required" {:type :bad-request})))

      (when (< (count query) 2)
        (throw (ex-info "Query must be at least 2 characters" {:type :bad-request})))

      (println "User" user-sub "searching for:" query)

      (let [limit (min limit max-limit)
            results (search-documents query limit)
            formatted (mapv format-search-result results)]

        (r/ok {:query query
               :results formatted
               :count (count formatted)})))

    (catch clojure.lang.ExceptionInfo e
      (let [data (ex-data e)]
        (case (:type data)
          :bad-request (r/bad-request (.getMessage e))
          (do
            (println "Error:" (.getMessage e))
            (r/internal-error "Search failed")))))

    (catch Exception e
      (println "Error searching:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Search failed"))))
