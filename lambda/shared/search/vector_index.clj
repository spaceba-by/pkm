(ns search.vector-index
  "Vector similarity search index for semantic search.
   Stores document chunk embeddings as a JSON index file in S3.
   Uses pure Clojure cosine similarity for search queries.

   Index format (JSON):
   {:schema_version 1
    :chunks [{:path \"docs/note.md\"
              :chunk_id 0
              :heading \"Introduction\"
              :content \"Text content...\"
              :embedding [0.1 0.2 ...]
              :updated_at \"2026-01-15T00:00:00Z\"}]}")

(defn dot-product
  "Compute dot product of two vectors"
  [a b]
  (reduce + (map * a b)))

(defn magnitude
  "Compute magnitude (L2 norm) of a vector"
  [v]
  (Math/sqrt (reduce + (map #(* % %) v))))

(defn cosine-similarity
  "Compute cosine similarity between two vectors. Returns 0.0 for zero vectors."
  [a b]
  (let [mag-a (magnitude a)
        mag-b (magnitude b)]
    (if (or (zero? mag-a) (zero? mag-b))
      0.0
      (/ (dot-product a b) (* mag-a mag-b)))))

(defn create-index
  "Create a new empty index"
  []
  {:schema_version 1
   :chunks []})

(defn- chunk-key
  "Unique key for a chunk: path + chunk_id"
  [chunk]
  [(:path chunk) (:chunk_id chunk)])

(defn upsert-chunks
  "Insert or replace chunks in the index. Chunks are matched by (path, chunk_id)."
  [index new-chunks]
  (let [new-keys (set (map chunk-key new-chunks))
        kept (remove #(new-keys (chunk-key %)) (:chunks index))]
    (assoc index :chunks (vec (concat kept new-chunks)))))

(defn remove-document
  "Remove all chunks for a given document path from the index"
  [index path]
  (update index :chunks (fn [chunks] (vec (remove #(= (:path %) path) chunks)))))

(defn search
  "Search the index for chunks similar to the query embedding.
   Returns top-k results sorted by descending cosine similarity.
   Each result includes :path :chunk_id :heading :content :score"
  [index query-embedding & {:keys [top-k min-score] :or {top-k 10 min-score 0.0}}]
  (->> (:chunks index)
       (map (fn [chunk]
              (let [score (cosine-similarity query-embedding (:embedding chunk))]
                (-> (dissoc chunk :embedding)
                    (assoc :score score)))))
       (filter #(>= (:score %) min-score))
       (sort-by :score >)
       (take top-k)
       vec))

(defn document-paths
  "Get the set of all document paths in the index"
  [index]
  (set (map :path (:chunks index))))

(defn chunk-count
  "Get the total number of chunks in the index"
  [index]
  (count (:chunks index)))
