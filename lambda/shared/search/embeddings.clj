(ns search.embeddings
  "Embedding generation using Amazon Bedrock Titan Embeddings or OpenAI API.
   Produces vector embeddings for text chunks used in semantic search."
  (:require [babashka.http-client :as http]
            [com.grzm.awyeah.client.api :as aws]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ^:private default-model "amazon.titan-embed-text-v2:0")
(def ^:private default-dimensions 1024)

;; --- Amazon Bedrock Titan Embeddings ---

(defn- bedrock-embedding-request
  "Build a Bedrock InvokeModel request for Titan Embeddings"
  [text model-id dimensions]
  (let [body {:inputText text
              :dimensions dimensions}]
    {:modelId model-id
     :contentType "application/json"
     :accept "application/json"
     :body (.getBytes (json/generate-string body) "UTF-8")}))

(defn generate-embedding-bedrock
  "Generate embedding for a single text using Bedrock Titan Embeddings.
   Requires a Bedrock runtime client (awyeah).
   Returns a vector of floats."
  [bedrock-client text & {:keys [model-id dimensions]
                          :or {model-id default-model
                               dimensions default-dimensions}}]
  (let [request (bedrock-embedding-request text model-id dimensions)
        response (aws/invoke bedrock-client
                              {:op :InvokeModel
                               :request request})]
    (when-let [error (:cognitect.anomalies/category response)]
      (throw (ex-info (str "Bedrock embedding failed: " (or (:message response) error))
                      {:error error :response response})))
    (let [parsed (json/parse-string (slurp (:body response)) true)]
      (:embedding parsed))))

(defn generate-embeddings-bedrock
  "Generate embeddings for multiple texts using Bedrock.
   Processes sequentially with optional delay between calls for rate limiting.
   Returns a vector of embedding vectors in the same order as input texts."
  [bedrock-client texts & {:keys [model-id dimensions delay-ms]
                           :or {model-id default-model
                                dimensions default-dimensions
                                delay-ms 0}}]
  (mapv (fn [text]
          (let [emb (generate-embedding-bedrock bedrock-client text
                                                :model-id model-id
                                                :dimensions dimensions)]
            (when (pos? delay-ms)
              (Thread/sleep delay-ms))
            emb))
        texts))

;; --- OpenAI Embeddings (alternative) ---

(defn generate-embedding-openai
  "Generate embedding using OpenAI text-embedding-3-small API.
   Requires OPENAI_API_KEY environment variable.
   Returns a vector of floats."
  [text & {:keys [api-key model]
           :or {model "text-embedding-3-small"}}]
  (let [api-key (or api-key (System/getenv "OPENAI_API_KEY"))
        _ (when (str/blank? api-key)
            (throw (ex-info "OPENAI_API_KEY not set" {})))
        response (http/post "https://api.openai.com/v1/embeddings"
                            {:headers {"Authorization" (str "Bearer " api-key)
                                       "Content-Type" "application/json"}
                             :body (json/generate-string
                                    {:model model
                                     :input text})})]
    (when-not (<= 200 (:status response) 299)
      (throw (ex-info (str "OpenAI embedding failed: HTTP " (:status response))
                      {:status (:status response) :body (:body response)})))
    (let [parsed (json/parse-string (:body response) true)]
      (get-in parsed [:data 0 :embedding]))))

(defn generate-embeddings-openai
  "Generate embeddings for multiple texts using OpenAI batch API.
   Returns a vector of embedding vectors in the same order as input texts."
  [texts & {:keys [api-key model]
            :or {model "text-embedding-3-small"}}]
  (let [api-key (or api-key (System/getenv "OPENAI_API_KEY"))
        _ (when (str/blank? api-key)
            (throw (ex-info "OPENAI_API_KEY not set" {})))
        response (http/post "https://api.openai.com/v1/embeddings"
                            {:headers {"Authorization" (str "Bearer " api-key)
                                       "Content-Type" "application/json"}
                             :body (json/generate-string
                                    {:model model
                                     :input texts})})]
    (when-not (<= 200 (:status response) 299)
      (throw (ex-info (str "OpenAI batch embedding failed: HTTP " (:status response))
                      {:status (:status response) :body (:body response)})))
    (let [parsed (json/parse-string (:body response) true)]
      (->> (:data parsed)
           (sort-by :index)
           (mapv :embedding)))))

;; --- Provider-agnostic interface ---

(defn make-embedding-fn
  "Create an embedding function based on provider configuration.
   Returns a function that takes a vector of texts and returns embeddings.
   Provider options:
     :bedrock  - uses Titan Embeddings via Bedrock (default)
     :openai   - uses OpenAI text-embedding-3-small"
  [provider & {:keys [bedrock-client model-id dimensions api-key]
               :or {dimensions default-dimensions}}]
  (case provider
    :bedrock
    (fn [texts]
      (generate-embeddings-bedrock bedrock-client texts
                                   :model-id (or model-id default-model)
                                   :dimensions dimensions
                                   :delay-ms 50))

    :openai
    (fn [texts]
      (generate-embeddings-openai texts
                                   :api-key api-key
                                   :model (or model-id "text-embedding-3-small")))))
