(ns aws.bedrock
  "AWS Bedrock client for Claude models"
  (:require [babashka.http-client :as http]
            [clojure.data.json :as json]
            [clojure.string :as str]))

(def ^:private bedrock-region (or (System/getenv "AWS_REGION") "us-east-1"))

(defn- bedrock-endpoint
  "Constructs Bedrock API endpoint"
  [model-id]
  (str "https://bedrock-runtime." bedrock-region ".amazonaws.com"
       "/model/" model-id "/invoke"))

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
        response (http/post (bedrock-endpoint model-id)
                           {:headers {"Content-Type" "application/json"}
                            :body (json/write-str body)
                            :aws/sign {:service "bedrock"
                                      :region bedrock-region}})]
    (json/read-str (:body response) :key-fn keyword)))

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
        response (invoke-model model-id prompt {:max-tokens 50 :temperature 0.3})]
    (-> response
        extract-text
        str/trim
        str/lower-case
        (str/replace #"[^a-z]" ""))))

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
  (let [{:keys [daily-summaries documents classifications]} week-data
        prompt (str "Create a comprehensive weekly review report based on this data:\n\n"
                   "## Daily Summaries\n"
                   (str/join "\n\n" (map :content daily-summaries))
                   "\n\n## Document Statistics\n"
                   "Total documents: " (count documents) "\n"
                   "By classification: " (pr-str classifications) "\n\n"
                   "Structure your report with:\n"
                   "1. Overview (2-3 sentences)\n"
                   "2. Key Themes (3-5 main themes)\n"
                   "3. Recommended Follow-ups (3-5 actionable items)\n\n"
                   "Be specific and actionable.")
        response (invoke-model model-id prompt {:max-tokens 6000 :temperature 0.7})]
    (extract-text response)))
