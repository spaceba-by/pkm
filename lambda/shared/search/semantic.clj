(ns search.semantic
  "Semantic search query interface.
   Loads the vector index from S3, embeds the query,
   and returns ranked results with similarity scores."
  (:require [search.vector-index :as vi]
            [search.indexer :as indexer]))

(defn search-semantic
  "Perform semantic search against the vector index.
   Takes an embed-fn (single text -> embedding vector), query text,
   and a pre-loaded index.
   Returns vector of {:path :heading :content :score :chunk_id}"
  [index embed-fn query & {:keys [top-k min-score] :or {top-k 10 min-score 0.3}}]
  (let [query-embedding (first (embed-fn [query]))]
    (vi/search index query-embedding :top-k top-k :min-score min-score)))

(defn search-with-index-load
  "Load index from S3, embed query, and return results.
   Convenience function for Lambda cold start."
  [bucket embed-fn query & {:keys [top-k min-score] :or {top-k 10 min-score 0.3}}]
  (let [index (indexer/load-index bucket)]
    (search-semantic index embed-fn query :top-k top-k :min-score min-score)))

(defn group-by-document
  "Group search results by document path, keeping the best score per document.
   Returns results sorted by best score descending."
  [results]
  (->> results
       (group-by :path)
       (map (fn [[path chunks]]
              (let [best (apply max-key :score chunks)]
                {:path path
                 :score (:score best)
                 :heading (:heading best)
                 :snippet (subs (:content best) 0 (min 200 (count (:content best))))
                 :chunk_count (count chunks)})))
       (sort-by :score >)
       vec))
