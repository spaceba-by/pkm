(ns command.context
  "Builds PKM context for the AI reasoning agent.
   Gathers relevant documents, entities, and summaries from DynamoDB/S3
   to provide context for answering user queries."
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [clojure.string :as str]))

(def ^:private max-doc-content-chars 2000)
(def ^:private max-relevant-docs 10)
(def ^:private max-summary-days 7)

(defn- extract-keywords
  "Extract simple keywords from command text for document matching"
  [command-text]
  (let [stop-words #{"the" "a" "an" "is" "are" "was" "were" "be" "been"
                      "being" "have" "has" "had" "do" "does" "did" "will"
                      "would" "could" "should" "may" "might" "shall" "can"
                      "my" "me" "i" "you" "your" "we" "our" "they" "their"
                      "it" "its" "this" "that" "these" "those" "what" "which"
                      "who" "whom" "how" "when" "where" "why" "in" "on" "at"
                      "to" "for" "of" "with" "by" "from" "about" "and" "or"
                      "not" "no" "all" "any" "some" "find" "get" "show"
                      "list" "summarize" "tell" "give" "last" "recent"}]
    (->> (str/split (str/lower-case command-text) #"\s+")
         (remove #(< (count %) 3))
         (remove stop-words)
         vec)))

(defn- gather-recent-documents
  "Fetch metadata for recently modified documents"
  [ddb-table]
  (let [since (str (.minus (java.time.Instant/now)
                           (java.time.Duration/ofDays 7)))]
    (try
      (let [docs (ddb/get-documents-modified-since ddb-table since)]
        (mapv (fn [doc]
                {:title (or (:title doc) (:document_path doc))
                 :path (:document_path doc)
                 :classification (:classification doc)
                 :tags (:tags doc)
                 :modified (:modified doc)})
              docs))
      (catch Exception e
        (println "Error gathering recent documents:" (ex-message e))
        []))))

(defn- gather-relevant-documents
  "Find documents matching keywords from the command, load truncated content"
  [ddb-table s3-bucket command-text]
  (let [keywords (extract-keywords command-text)]
    (if (empty? keywords)
      []
      (try
        ;; Search by tags that match keywords
        (let [tag-results (mapcat #(ddb/query-by-tag ddb-table %) keywords)
              doc-paths (distinct (map :document_path tag-results))
              limited-paths (take max-relevant-docs doc-paths)]
          (vec
           (keep
            (fn [path]
              (try
                (let [content (s3/get-object s3-bucket path)
                      truncated (subs content 0 (min (count content) max-doc-content-chars))]
                  {:path path
                   :content truncated})
                (catch Exception _
                  nil)))
            limited-paths)))
        (catch Exception e
          (println "Error gathering relevant documents:" (ex-message e))
          [])))))

(defn- gather-recent-summaries
  "Load recent daily summaries from S3"
  [s3-bucket]
  (try
    (let [now (java.time.LocalDate/now)
          dates (map #(.minusDays now %) (range max-summary-days))]
      (vec
       (keep
        (fn [date]
          (when-let [content (s3/get-daily-summary s3-bucket (str date))]
            {:date (str date)
             :content content}))
        dates)))
    (catch Exception e
      (println "Error gathering summaries:" (ex-message e))
      [])))

(defn- format-context
  "Assemble gathered data into a structured context string"
  [{:keys [recent-docs relevant-docs summaries]}]
  (let [sections []
        sections (if (seq recent-docs)
                   (conj sections
                         (str "## Recent Documents (last 7 days)\n\n"
                              (str/join "\n"
                                        (map (fn [{:keys [title classification tags modified]}]
                                               (str "- **" title "**"
                                                    (when classification (str " [" classification "]"))
                                                    (when (seq tags) (str " tags: " (str/join ", " tags)))
                                                    (when modified (str " (modified: " modified ")"))))
                                             recent-docs))))
                   sections)
        sections (if (seq relevant-docs)
                   (conj sections
                         (str "## Relevant Document Content\n\n"
                              (str/join "\n\n---\n\n"
                                        (map (fn [{:keys [path content]}]
                                               (str "### " path "\n\n" content))
                                             relevant-docs))))
                   sections)
        sections (if (seq summaries)
                   (conj sections
                         (str "## Recent Daily Summaries\n\n"
                              (str/join "\n\n"
                                        (map (fn [{:keys [date content]}]
                                               (str "### " date "\n\n" content))
                                             summaries))))
                   sections)]
    (if (seq sections)
      (str/join "\n\n" sections)
      "No relevant context found in the knowledge base.")))

(defn build-context
  "Build PKM context for the AI agent based on the command/query text.
   Returns a formatted string with relevant documents, entities, and summaries."
  [ddb-table s3-bucket command-text]
  (let [recent-docs (gather-recent-documents ddb-table)
        relevant-docs (gather-relevant-documents ddb-table s3-bucket command-text)
        summaries (gather-recent-summaries s3-bucket)]
    (format-context {:recent-docs recent-docs
                     :relevant-docs relevant-docs
                     :summaries summaries})))
