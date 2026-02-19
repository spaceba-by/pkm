(ns search.indexer
  "Indexing pipeline for semantic search.
   Detects changed documents, chunks them, generates embeddings,
   and upserts into the vector index. Persists the index to/from S3."
  (:require [aws.s3 :as s3]
            [aws.dynamodb :as ddb]
            [search.chunker :as chunker]
            [search.vector-index :as vi]
            [cheshire.core :as json]
            [clojure.string :as str]
            [markdown.utils :as md]
            [clojure.set :as set]))

(def ^:private index-s3-key "_agent/search/vector-index.json")

(defn load-index
  "Load the vector index from S3. Returns a new empty index if not found."
  [bucket]
  (try
    (let [content (s3/get-object bucket index-s3-key)]
      (json/parse-string content true))
    (catch Exception _
      (println "No existing index found, creating new one")
      (vi/create-index))))

(defn save-index
  "Save the vector index to S3 as JSON"
  [bucket index]
  (let [content (json/generate-string index)]
    (s3/put-object bucket index-s3-key content)
    (println "Saved index with" (vi/chunk-count index) "chunks")))

(defn- get-document-content
  "Get document content from S3"
  [bucket path]
  (s3/get-object bucket path))

(defn- should-index?
  "Check if a document path should be indexed"
  [path]
  (and (str/ends-with? path ".md")
       (not (str/starts-with? path "_agent/"))
       (not (str/starts-with? path ".obsidian/"))))

(defn get-changed-documents
  "Get documents that have been modified since the index was last updated.
   Compares DynamoDB modified timestamps against index updated_at timestamps."
  [table index]
  (let [indexed-times (into {}
                            (map (fn [chunk]
                                   [(:path chunk) (:updated_at chunk)])
                                 (:chunks index)))
        all-docs (ddb/scan-all table
                               :filter-expr "SK = :sk"
                               :expr-attr-values {":sk" "METADATA"})
        changed (filter (fn [doc]
                          (let [path (:PK doc)
                                modified (:modified doc)
                                indexed-at (get indexed-times path)]
                            (and (should-index? path)
                                 (or (nil? indexed-at)
                                     (and modified
                                          (pos? (compare modified indexed-at)))))))
                        all-docs)]
    (mapv :PK changed)))

(defn get-deleted-documents
  "Get document paths that are in the index but no longer in DynamoDB"
  [table index]
  (let [indexed-paths (vi/document-paths index)
        existing-docs (ddb/scan-all table
                                    :filter-expr "SK = :sk"
                                    :expr-attr-values {":sk" "METADATA"})
        existing-paths (set (map :PK existing-docs))]
    (vec (set/difference indexed-paths existing-paths))))

(defn index-document
  "Index a single document: chunk it and generate embeddings.
   Returns a vector of chunks with embeddings ready for upserting."
  [bucket path embed-fn]
  (let [content (get-document-content bucket path)
        [frontmatter _body] (md/extract-frontmatter content)
        title (md/extract-title content frontmatter)
        chunks (chunker/chunk-document path content :title title)
        now (md/now-iso)]
    (when (seq chunks)
      (let [texts (mapv :content chunks)
            embeddings (embed-fn texts)]
        (mapv (fn [chunk embedding]
                (assoc chunk
                       :embedding embedding
                       :updated_at now))
              chunks embeddings)))))

(defn index-documents
  "Index multiple documents and update the vector index.
   Returns the updated index."
  [bucket _table embed-fn index paths & {:keys [on-progress]}]
  (reduce (fn [idx path]
            (try
              (println "Indexing:" path)
              (if-let [chunks (index-document bucket path embed-fn)]
                (let [updated (vi/upsert-chunks idx chunks)]
                  (when on-progress (on-progress path (count chunks)))
                  updated)
                (do
                  (println "No chunks produced for:" path)
                  idx))
              (catch Exception e
                (println "Error indexing" path ":" (ex-message e))
                idx)))
          index
          paths))

(defn remove-deleted
  "Remove deleted documents from the index. Returns updated index."
  [index deleted-paths]
  (reduce (fn [idx path]
            (println "Removing from index:" path)
            (vi/remove-document idx path))
          index
          deleted-paths))

(defn run-incremental-index
  "Run an incremental indexing pass:
   1. Load existing index from S3
   2. Find changed and deleted documents
   3. Re-index changed documents
   4. Remove deleted documents
   5. Save updated index to S3
   Returns {:indexed n :removed m :total t}"
  [bucket table embed-fn]
  (let [index (load-index bucket)
        changed (get-changed-documents table index)
        deleted (get-deleted-documents table index)
        _ (println "Found" (count changed) "changed," (count deleted) "deleted documents")
        index (if (seq changed)
                (index-documents bucket table embed-fn index changed)
                index)
        index (if (seq deleted)
                (remove-deleted index deleted)
                index)]
    (when (or (seq changed) (seq deleted))
      (save-index bucket index))
    {:indexed (count changed)
     :removed (count deleted)
     :total (vi/chunk-count index)}))
