(ns handler
  "API Lambda: Search documents by query.
   Supports keyword search (default) and semantic search (mode=semantic)."
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [search.vector-index :as vi]
            [search.indexer :as indexer]
            [search.semantic :as semantic]
            [search.embeddings :as emb]
            [com.grzm.awyeah.client.api :as aws]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def embedding-model-id (or (System/getenv "EMBEDDING_MODEL_ID")
                            "amazon.titan-embed-text-v2:0"))
(def default-limit 20)
(def max-limit 50)

;; Cached index - loaded once per Lambda cold start
(defonce ^:private cached-index (atom nil))

(defn- get-index
  "Get the vector index, loading from S3 on first call"
  []
  (or @cached-index
      (let [index (indexer/load-index s3-bucket)]
        (reset! cached-index index)
        index)))

(defn get-all-documents
  "Get all document metadata for client-side search"
  []
  (ddb/scan-all ddb-table
                :filter-expr "SK = :sk"
                :expr-attr-values {":sk" "METADATA"}))

(defn matches-query?
  "Check if document matches search query (case-insensitive)"
  [doc query-lower]
  (let [title (str/lower-case (or (:title doc) ""))
        tags (or (:tags doc) [])
        pk (str/lower-case (or (:PK doc) ""))]
    (or (str/includes? title query-lower)
        (str/includes? pk query-lower)
        (some #(str/includes? (str/lower-case %) query-lower) tags))))

(defn search-documents-keyword
  "Search documents by title, path, and tags using keyword matching.
   Scans all documents in DynamoDB and filters in memory."
  [query limit]
  (let [query-lower (str/lower-case query)
        all-docs (get-all-documents)]
    (->> all-docs
         (filter #(matches-query? % query-lower))
         (take limit)
         (vec))))

(defn- make-embed-fn
  "Create an embedding function using Bedrock Titan"
  []
  (let [client (aws/client {:api :bedrock-runtime})]
    (emb/make-embedding-fn :bedrock
                           :bedrock-client client
                           :model-id embedding-model-id)))

(defn search-documents-semantic
  "Search documents using semantic (vector similarity) search.
   Returns results with similarity scores."
  [query limit]
  (let [index (get-index)]
    (if (zero? (vi/chunk-count index))
      []
      (let [embed-fn (make-embed-fn)
            results (semantic/search-semantic index embed-fn query
                                             :top-k (* limit 3)
                                             :min-score 0.3)
            grouped (semantic/group-by-document results)]
        (take limit grouped)))))

(def default-timestamp "1970-01-01T00:00:00Z")

(defn format-keyword-result
  "Format document for keyword search results.
   Returns nested metadata structure matching iOS Document model."
  [doc]
  (let [modified (r/truncate-timestamp (or (:modified doc) default-timestamp))
        created (r/truncate-timestamp (or (:created doc) modified))]
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

(defn- format-semantic-result
  "Format a semantic search result.
   Includes similarity score and content snippet."
  [result ddb-table]
  (let [doc (ddb/get-item ddb-table {:PK (:path result) :SK "METADATA"})
        modified (r/truncate-timestamp (or (:modified doc) default-timestamp))
        created (r/truncate-timestamp (or (:created doc) modified))]
    {:id (:path result)
     :title (or (:title doc) "Untitled")
     :score (:score result)
     :heading (:heading result)
     :snippet (:snippet result)
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
  "Lambda handler for GET /search?q=...&mode=keyword|semantic"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          params (r/parse-query-params event)
          query (or (get params :q) (get params "q"))
          mode (or (get params :mode) (get params "mode") "keyword")
          limit (r/parse-int-param params "limit" default-limit)
          user-sub (r/get-user-sub event)]

      (when (or (nil? query) (str/blank? query))
        (throw (ex-info "Query parameter 'q' is required" {:type :bad-request})))

      (when (< (count query) 2)
        (throw (ex-info "Query must be at least 2 characters" {:type :bad-request})))

      (println "User" user-sub "searching for:" query "(mode:" mode ")")

      (let [limit (min limit max-limit)]
        (case mode
          "semantic"
          (let [results (search-documents-semantic query limit)
                formatted (mapv #(format-semantic-result % ddb-table) results)]
            (r/ok {:query query
                   :mode "semantic"
                   :results formatted
                   :count (count formatted)}))

          ;; Default: keyword search
          (let [results (search-documents-keyword query limit)
                formatted (mapv format-keyword-result results)]
            (r/ok {:query query
                   :mode "keyword"
                   :results formatted
                   :count (count formatted)})))))

    (catch clojure.lang.ExceptionInfo e
      (let [data (ex-data e)]
        (case (:type data)
          :bad-request (r/bad-request (ex-message e))
          (do
            (println "Error:" (ex-message e))
            (r/internal-error "Search failed")))))

    (catch Exception e
      (println "Error searching:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Search failed"))))
