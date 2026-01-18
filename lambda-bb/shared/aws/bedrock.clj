(ns aws.bedrock
  "AWS Bedrock client for Claude models using awyeah"
  (:require [com.grzm.awyeah.client.api :as aws]
            [clojure.data.json :as json]
            [clojure.string :as str]))

(defonce ^:private bedrock-client
  (delay (aws/client {:api :bedrock-runtime})))

(defn- check-error
  "Check AWS response for errors and throw if found"
  [response operation]
  (when-let [error-category (:cognitect.anomalies/category response)]
    (throw (ex-info (str "Bedrock " operation " failed: "
                         (or (:message response) error-category))
                    {:operation operation
                     :error-category error-category
                     :error-code (:cognitect.aws.error/code response)
                     :response response})))
  response)

(defn invoke-model
  "Invokes Bedrock Claude model with prompt
   Options:
   - :max-tokens (default 2048)
   - :temperature (default 1.0)
   - :system (optional system prompt)"
  [model-id prompt & [{:keys [max-tokens temperature system]
                       :or {max-tokens 2048 temperature 1.0}}]]
  (let [body (cond-> {:anthropic_version "bedrock-2023-05-31"
                      :max_tokens max-tokens
                      :temperature temperature
                      :messages [{:role "user"
                                 :content prompt}]}
               system (assoc :system system))
        response (-> (aws/invoke @bedrock-client
                                 {:op :InvokeModel
                                  :request {:modelId model-id
                                           :contentType "application/json"
                                           :accept "application/json"
                                           :body (.getBytes (json/write-str body) "UTF-8")}})
                     (check-error "InvokeModel"))]
    (json/read-str (slurp (:body response)) :key-fn keyword)))

(defn extract-text
  "Extracts text content from Bedrock response"
  [response]
  (-> response :content first :text))

(defn classify-document
  "Classifies document into one of: meeting, idea, reference, journal, project"
  [model-id content metadata]
  (let [title (get metadata :title "Untitled")
        prompt (str "Classify this document into exactly one of these categories: "
                   "meeting, idea, reference, journal, project\n\n"
                   "Title: " title "\n\n"
                   "Content:\n" content "\n\n"
                   "Return ONLY the classification category name, nothing else.")
        response (invoke-model model-id prompt {:max-tokens 50 :temperature 0.3})
        text (extract-text response)]
    (when text
      (-> text
          str/trim
          str/lower-case
          (str/replace #"[^a-z]" "")))))

(defn extract-entities
  "Extracts named entities (people, organizations, concepts, locations)"
  [model-id content]
  (let [prompt (str "Extract named entities from this text and return them as a JSON object.\n\n"
                   "The JSON must have exactly these keys:\n"
                   "- \"people\": array of person names\n"
                   "- \"organizations\": array of organization names\n"
                   "- \"concepts\": array of key concepts/topics\n"
                   "- \"locations\": array of place names\n\n"
                   "Return ONLY valid JSON, no additional text.\n\n"
                   "Text:\n" content)
        response (invoke-model model-id prompt {:max-tokens 1000 :temperature 0.5})]
    (try
      (json/read-str (extract-text response) :key-fn keyword)
      (catch Exception e
        (println "Error parsing entities response:" (.getMessage e))
        {:people [] :organizations [] :concepts [] :locations []}))))

(defn generate-summary
  "Generates summary from multiple documents"
  [model-id documents]
  (let [doc-text (str/join "\n\n---\n\n"
                          (map (fn [{:keys [title content]}]
                                 (str "## " title "\n\n" content))
                               documents))
        prompt (str "Create a concise summary of the following documents. "
                   "Focus on key themes, important information, and connections between documents.\n\n"
                   doc-text)
        response (invoke-model model-id prompt {:max-tokens 4000 :temperature 0.7})]
    (extract-text response)))

(defn generate-weekly-report
  "Generates comprehensive weekly report"
  [model-id week-data]
  (let [{:keys [daily_summaries documents classification_counts]} week-data
        prompt (str "Create a comprehensive weekly review report based on this data:\n\n"
                   "## Daily Summaries\n"
                   (str/join "\n\n" (map :content daily_summaries))
                   "\n\n## Document Statistics\n"
                   "Total documents: " (count documents) "\n"
                   "By classification: " (pr-str classification_counts) "\n\n"
                   "Structure your report with:\n"
                   "1. Overview (2-3 sentences)\n"
                   "2. Key Themes (3-5 main themes)\n"
                   "3. Recommended Follow-ups (3-5 actionable items)\n\n"
                   "Be specific and actionable.")
        response (invoke-model model-id prompt {:max-tokens 6000 :temperature 0.7})]
    (extract-text response)))
