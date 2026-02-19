#!/usr/bin/env bb

;; Batch indexing script for semantic search.
;; Indexes document chunks with embeddings into the vector search index.
;;
;; Usage:
;;   bb scripts/index-embeddings.clj --help
;;   bb scripts/index-embeddings.clj --dry-run              # Show what would be indexed
;;   bb scripts/index-embeddings.clj --execute              # Run incremental index
;;   bb scripts/index-embeddings.clj --execute --full       # Full reindex
;;   bb scripts/index-embeddings.clj --execute --prefix notes/  # Index only prefix
;;   bb scripts/index-embeddings.clj --stats                # Show index statistics

(require '[babashka.deps :as deps])

(deps/add-deps
 '{:deps {com.grzm/awyeah-api {:git/url "https://github.com/grzm/awyeah-api"
                                :git/sha "e5513349a2fd8a980a62bbe0d45a0d55bfcea141"}
          com.cognitect.aws/endpoints {:mvn/version "1.1.12.772"}
          com.cognitect.aws/s3 {:mvn/version "848.2.1413.0"}
          com.cognitect.aws/dynamodb {:mvn/version "848.2.1413.0"}
          com.cognitect.aws/bedrock-runtime {:mvn/version "871.2.30.11"}
          org.babashka/http-client {:mvn/version "0.4.19"}}})

;; Add lambda shared code to classpath
(deps/add-deps '{:deps {} :paths ["lambda/shared"]})

(require '[com.grzm.awyeah.client.api :as aws]
         '[cheshire.core :as json]
         '[clojure.string :as str]
         '[aws.s3 :as s3]
         '[aws.dynamodb :as ddb]
         '[search.vector-index :as vi]
         '[search.indexer :as indexer]
         '[search.chunker :as chunker]
         '[search.embeddings :as emb]
         '[markdown.utils :as md])

(def s3-bucket (or (System/getenv "S3_BUCKET_NAME") "pkm-vault"))
(def ddb-table (or (System/getenv "DYNAMODB_TABLE_NAME") "pkm-documents"))
(def embedding-model (or (System/getenv "EMBEDDING_MODEL_ID") "amazon.titan-embed-text-v2:0"))

(defn parse-args [args]
  (loop [remaining args
         opts {:mode :help}]
    (if (empty? remaining)
      opts
      (let [arg (first remaining)]
        (case arg
          "--help"    (recur (rest remaining) (assoc opts :mode :help))
          "--dry-run" (recur (rest remaining) (assoc opts :mode :dry-run))
          "--execute" (recur (rest remaining) (assoc opts :mode :execute))
          "--stats"   (recur (rest remaining) (assoc opts :mode :stats))
          "--full"    (recur (rest remaining) (assoc opts :full true))
          "--prefix"  (if (second remaining)
                        (recur (drop 2 remaining) (assoc opts :prefix (second remaining)))
                        (do (println "Missing value for --prefix")
                            (assoc opts :mode :help)))
          "--limit"   (if (second remaining)
                        (try
                          (recur (drop 2 remaining) (assoc opts :limit (Integer/parseInt (second remaining))))
                          (catch NumberFormatException _
                            (println "Invalid value for --limit; must be an integer")
                            (assoc opts :mode :help)))
                        (do (println "Missing value for --limit")
                            (assoc opts :mode :help)))
          (do (println "Unknown option:" arg)
              (recur (rest remaining) opts)))))))

(defn show-help []
  (println "Usage: bb scripts/index-embeddings.clj [OPTIONS]")
  (println)
  (println "Options:")
  (println "  --help              Show this help message")
  (println "  --dry-run           Show what documents would be indexed")
  (println "  --execute           Run the indexing pipeline")
  (println "  --stats             Show index statistics")
  (println "  --full              Full reindex (delete existing index first)")
  (println "  --prefix PREFIX     Only index documents with this path prefix")
  (println "  --limit N           Limit number of documents to index")
  (println)
  (println "Environment variables:")
  (println "  S3_BUCKET_NAME       S3 bucket (default: pkm-vault)")
  (println "  DYNAMODB_TABLE_NAME  DynamoDB table (default: pkm-documents)")
  (println "  EMBEDDING_MODEL_ID   Bedrock model (default: amazon.titan-embed-text-v2:0)"))

(defn show-stats []
  (println "Loading index from S3...")
  (let [index (indexer/load-index s3-bucket)]
    (println)
    (println "Index Statistics:")
    (println "  Schema version:" (:schema_version index))
    (println "  Total chunks:" (vi/chunk-count index))
    (println "  Total documents:" (count (vi/document-paths index)))
    (when (pos? (vi/chunk-count index))
      (let [paths (sort (vi/document-paths index))]
        (println)
        (println "Indexed documents:")
        (doseq [path paths]
          (let [doc-chunks (filter #(= (:path %) path) (:chunks index))]
            (println (str "  " path " (" (count doc-chunks) " chunks)"))))))))

(defn dry-run [opts]
  (println "Loading index from S3...")
  (let [index (if (:full opts)
                (vi/create-index)
                (indexer/load-index s3-bucket))
        changed (indexer/get-changed-documents ddb-table index)
        deleted (indexer/get-deleted-documents ddb-table index)
        changed (if-let [prefix (:prefix opts)]
                  (filter #(str/starts-with? % prefix) changed)
                  changed)
        changed (if-let [limit (:limit opts)]
                  (take limit changed)
                  changed)]
    (println)
    (println "Documents to index:" (count changed))
    (doseq [path changed]
      (println "  [INDEX]" path))
    (println)
    (println "Documents to remove:" (count deleted))
    (doseq [path deleted]
      (println "  [REMOVE]" path))))

(defn execute [opts]
  (println "Starting indexing pipeline...")
  (println "  Bucket:" s3-bucket)
  (println "  Table:" ddb-table)
  (println "  Model:" embedding-model)
  (println "  Mode:" (if (:full opts) "full reindex" "incremental"))
  (println)

  (let [bedrock-client (aws/client {:api :bedrock-runtime})
        embed-fn (emb/make-embedding-fn :bedrock
                                        :bedrock-client bedrock-client
                                        :model-id embedding-model)
        index (if (:full opts)
                (vi/create-index)
                (indexer/load-index s3-bucket))
        changed (indexer/get-changed-documents ddb-table index)
        deleted (indexer/get-deleted-documents ddb-table index)
        changed (if-let [prefix (:prefix opts)]
                  (filter #(str/starts-with? % prefix) changed)
                  changed)
        changed (if-let [limit (:limit opts)]
                  (vec (take limit changed))
                  (vec changed))
        start-time (System/currentTimeMillis)]

    (println "Found" (count changed) "documents to index," (count deleted) "to remove")
    (println)

    (let [indexed-count (atom 0)
          index (indexer/index-documents
                 s3-bucket ddb-table embed-fn index changed
                 :on-progress (fn [path chunks]
                                (swap! indexed-count inc)
                                (println (str "  [" @indexed-count "/" (count changed) "] "
                                                        path " (" chunks " chunks)"))))
          index (indexer/remove-deleted index (vec deleted))
          elapsed (/ (- (System/currentTimeMillis) start-time) 1000.0)]

      (when (or (seq changed) (seq deleted))
        (indexer/save-index s3-bucket index))

      (println)
      (println "Indexing complete in" (format "%.1f" elapsed) "seconds")
      (println "  Indexed:" (count changed) "documents")
      (println "  Removed:" (count deleted) "documents")
      (println "  Total chunks:" (vi/chunk-count index))
      (println "  Total documents:" (count (vi/document-paths index))))))

(let [opts (parse-args *command-line-args*)]
  (case (:mode opts)
    :help (show-help)
    :dry-run (dry-run opts)
    :execute (execute opts)
    :stats (show-stats)
    (show-help)))
