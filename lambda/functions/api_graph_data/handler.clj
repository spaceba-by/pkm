(ns handler
  "API Lambda: Return knowledge graph data (nodes and edges) for visualization.
   Builds a graph from documents, entities, tags, and their relationships."
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

;; Lambda Runtime API payload limit is 6 MB; keep response well under
(def max-body-bytes (* 5 1024 1024))

(def entity-types #{"people" "organizations" "concepts" "locations"})

(defn- entity-node-id
  "Create a stable node ID for an entity"
  [entity-type entity-name]
  (str "entity:" entity-type ":" (str/lower-case entity-name)))

(defn- tag-node-id
  "Create a stable node ID for a tag"
  [tag-name]
  (str "tag:" (str/lower-case tag-name)))

(defn- doc-node-id
  "Create a stable node ID for a document"
  [doc-path]
  (str "doc:" doc-path))

(defn- extract-title-from-path
  "Extract a display title from a document path"
  [path]
  (-> path
      (str/split #"/")
      last
      (str/replace #"\.md$" "")
      (str/replace #"[-_]" " ")))

(defn build-graph
  "Build graph nodes and edges from document metadata.
   Accepts a collection of document metadata items.
   Returns {:nodes [...] :edges [...]}."
  [documents]
  (let [nodes (atom {})
        edges (atom [])
        edge-set (atom #{})

        add-node! (fn [id node-data]
                    (swap! nodes assoc id node-data))

        add-edge! (fn [source target edge-type weight]
                    ;; Directional edge types preserve source/target order;
                    ;; undirected types sort to deduplicate
                    (let [directional? (#{"links_to"} edge-type)
                          edge-key (if (or directional?
                                           (neg? (compare source target)))
                                     [source target edge-type]
                                     [target source edge-type])]
                      (when-not (contains? @edge-set edge-key)
                        (swap! edge-set conj edge-key)
                        (swap! edges conj {:source source
                                           :target target
                                           :type edge-type
                                           :weight (or weight 1)}))))]

    ;; Pass 1: Create document nodes and collect entity/tag info
    (doseq [doc documents]
      (let [doc-path (:PK doc)
            doc-id (doc-node-id doc-path)
            title (or (:title doc) (extract-title-from-path doc-path))
            classification (or (:classification doc) "reference")
            entities (or (:entities doc) {})
            tags (or (:tags doc) [])
            links-to (or (:links_to doc) [])]

        ;; Add document node
        (add-node! doc-id {:id doc-id
                           :type "document"
                           :label title
                           :path doc-path
                           :classification classification})

        ;; Add entity nodes and document->entity edges
        (doseq [entity-type entity-types]
          (let [type-key (keyword entity-type)
                entity-names (get entities type-key [])]
            (doseq [entity-name entity-names
                    :when (and entity-name (not (str/blank? entity-name)))]
              (let [eid (entity-node-id entity-type entity-name)]
                (add-node! eid {:id eid
                                :type "entity"
                                :label entity-name
                                :entityType entity-type})
                (add-edge! doc-id eid "mentions" 1)))))

        ;; Add tag nodes and document->tag edges
        (doseq [tag tags
                :when (and tag (not (str/blank? tag)))]
          (let [tid (tag-node-id tag)]
            (add-node! tid {:id tid
                            :type "tag"
                            :label tag})
            (add-edge! doc-id tid "tagged" 1)))

        ;; Add document->document edges from wikilinks
        (doseq [link links-to
                :when (and link (not (str/blank? link)))]
          (let [link-path (if (str/ends-with? link ".md") link (str link ".md"))
                link-id (doc-node-id link-path)]
            (add-edge! doc-id link-id "links_to" 2)))))

    ;; Pass 2: Add co-occurrence edges between entities in the same document
    (doseq [doc documents]
      (let [entities (or (:entities doc) {})
            all-entity-ids (for [entity-type entity-types
                                 entity-name (get entities (keyword entity-type) [])
                                 :when (and entity-name (not (str/blank? entity-name)))]
                             (entity-node-id entity-type entity-name))
            ;; Deduplicate entities per document to avoid self-edges and redundant edges
            unique-entity-ids (distinct all-entity-ids)]
        (doseq [[i a] (map-indexed vector unique-entity-ids)
                b (drop (inc i) unique-entity-ids)
                :when (not= a b)]
          (add-edge! a b "co_occurrence" 1))))

    {:nodes (vec (vals @nodes))
     :edges @edges}))

(defn handler
  "Lambda handler for GET /graph"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          params (r/parse-query-params event)
          user-sub (r/get-user-sub event)
          limit (min (or (some-> (or (get params :limit) (get params "limit"))
                                 parse-long)
                         500)
                     1000)

          _ (println "User" user-sub "requesting graph data, limit:" limit)

          ;; Fetch document metadata with limit to prevent unbounded scans
          [documents _] (ddb/scan-to-limit ddb-table
                                           :filter-expr "SK = :sk"
                                           :expr-attr-values {":sk" "METADATA"}
                                           :limit limit)

          _ (println "Found" (count documents) "documents for graph")

          ;; Build the graph
          graph (build-graph documents)
          body {:nodes (:nodes graph)
                :edges (:edges graph)
                :nodeCount (count (:nodes graph))
                :edgeCount (count (:edges graph))}
          body-json (json/generate-string body)
          body-size (count (.getBytes body-json "UTF-8"))]

      (println "Graph response size:" body-size "bytes,"
               (count (:nodes graph)) "nodes,"
               (count (:edges graph)) "edges")

      (if (> body-size max-body-bytes)
        (r/bad-request (str "Graph too large (" body-size " bytes). "
                            "Try a smaller limit (current: " limit ")."))
        {:statusCode 200
         :headers {"Content-Type" "application/json"
                   "Cache-Control" "private, max-age=300"}
         :body body-json}))

    (catch Exception e
      (println "Error building graph data:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to build graph data"))))
