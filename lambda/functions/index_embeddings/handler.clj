(ns handler
  "Lambda function to run incremental embedding indexing.
   Triggered on schedule (e.g., every 6 hours) or manually via API.
   Detects changed/deleted documents and updates the vector search index."
  (:require [search.indexer :as indexer]
            [search.embeddings :as emb]
            [com.grzm.awyeah.client.api :as aws]
            [cheshire.core :as json]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def embedding-model-id (or (System/getenv "EMBEDDING_MODEL_ID")
                            "amazon.titan-embed-text-v2:0"))

(defn handler
  "Lambda handler for scheduled or manual indexing invocation"
  [_request]
  (try
    (println "Starting embedding index update...")
    (println "  Bucket:" s3-bucket)
    (println "  Table:" ddb-table)
    (println "  Model:" embedding-model-id)

    (let [bedrock-client (aws/client {:api :bedrock-runtime})
          embed-fn (emb/make-embedding-fn :bedrock
                                          :bedrock-client bedrock-client
                                          :model-id embedding-model-id)
          result (indexer/run-incremental-index s3-bucket ddb-table embed-fn)]

      (println "Indexing complete:" result)

      {:statusCode 200
       :body (json/generate-string {:message "Index updated"
                                    :indexed (:indexed result)
                                    :removed (:removed result)
                                    :total_chunks (:total result)})})

    (catch Exception e
      (println "Error during indexing:" (ex-message e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:error (ex-message e)})})))
