(ns aws.bedrock
  "AWS Bedrock client for Claude models using awyeah"
  (:require [com.grzm.awyeah.client.api :as aws]
            [cheshire.core :as json]
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
                                           :body (.getBytes (json/generate-string body) "UTF-8")}})
                     (check-error "InvokeModel"))]
    (json/parse-string (slurp (:body response)) true)))

(defn extract-text
  "Extracts text content from Bedrock response"
  [response]
  (-> response :content first :text))

(defn- strip-markdown-fences
  "Strip markdown code fences from LLM response text"
  [text]
  (-> text
      str/trim
      (str/replace #"^```(?:json)?\s*\n?" "")
      (str/replace #"\n?\s*```$" "")
      str/trim))

(def ^:private valid-classifications
  #{"meeting" "idea" "reference" "journal" "project"})

(def ^:private classification-system-prompt
  "You are a document classifier for a Personal Knowledge Management (PKM) system based on Obsidian markdown files.

Your task is to classify documents into exactly one of these categories:

- **meeting**: Meeting notes, agendas, minutes, standups, 1:1s, retrospectives. Signals: attendee names, dates/times, action items, agenda headings, phrases like \"discussed\", \"agreed\", \"follow-up\".
- **idea**: Brainstorms, concepts, proposals, feature ideas, rough drafts of new thinking. Signals: speculative language (\"what if\", \"could we\", \"might be interesting\"), bullet-point lists of possibilities, no formal structure.
- **reference**: Documentation, how-to guides, technical notes, bookmarks, saved articles, API references, cheat sheets. Signals: instructional tone, code blocks, step-by-step lists, links to external resources, factual/explanatory content.
- **journal**: Daily logs, reflections, personal entries, stream-of-consciousness writing. Signals: first-person narrative, date in title or frontmatter, emotional/reflective language, daily routine mentions.
- **project**: Project plans, task tracking, roadmaps, sprint plans, project status updates. Signals: task lists with checkboxes, milestones, deadlines, status indicators (done/in-progress/blocked), project-specific tags.

Respond with a JSON object containing:
- \"classification\": one of the category names above
- \"confidence\": a number from 0.0 to 1.0 indicating how confident you are

Return ONLY valid JSON, no additional text.")

(defn classify-document
  "Classifies document into one of: meeting, idea, reference, journal, project.
   Returns map with :classification and :confidence keys."
  [model-id content metadata]
  (let [title (get metadata :title "Untitled")
        tags (get metadata :tags [])
        frontmatter-type (get metadata :type)
        wikilinks (get metadata :links_to [])
        prompt (str "Classify this document.\n\n"
                   "Title: " title "\n"
                   (when (seq tags) (str "Tags: " (str/join ", " tags) "\n"))
                   (when frontmatter-type (str "Frontmatter type: " frontmatter-type "\n"))
                   (when (seq wikilinks) (str "Wikilink count: " (count wikilinks) "\n"))
                   "\nContent:\n" content)
        response (invoke-model model-id prompt
                               {:max-tokens 100
                                :temperature 0.2
                                :system classification-system-prompt})
        text (extract-text response)]
    (try
      (let [cleaned (strip-markdown-fences text)
            parsed (json/parse-string cleaned true)
            classification (some-> (:classification parsed)
                                   str/trim
                                   str/lower-case)
            confidence (or (:confidence parsed) 0.0)]
        (if (valid-classifications classification)
          {:classification classification
           :confidence (double confidence)}
          {:classification "reference"
           :confidence 0.0}))
      (catch Exception e
        (println "Error parsing classification response:" (ex-message e) "raw:" text)
        {:classification "reference"
         :confidence 0.0})))))

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
      (json/parse-string (strip-markdown-fences (extract-text response)) true)
      (catch Exception e
        (println "Error parsing entities response:" (ex-message e))
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
