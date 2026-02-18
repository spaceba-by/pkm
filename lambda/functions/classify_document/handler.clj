(ns handler
  "Lambda function to classify markdown documents using Bedrock"
  (:require [aws.s3 :as s3]
            [aws.dynamodb :as ddb]
            [aws.bedrock :as bedrock]
            [markdown.utils :as md]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def bedrock-model (System/getenv "BEDROCK_MODEL_ID"))

(defn should-skip?
  "Check if file should be skipped"
  [object-key]
  (or
   ;; Skip non-markdown files
   (not (.endsWith object-key ".md"))
   ;; Skip _agent directory
   (.startsWith object-key "_agent/")
   (re-find #"/_agent/" object-key)
   ;; Skip .obsidian directory
   (.startsWith object-key ".obsidian/")
   (re-find #"/\.obsidian/" object-key)))

;; Frontmatter signal rules: vectors of [classification signal-set] pairs.
;; Order defines priority when a document matches multiple classifications.
(def ^:private tag-signals
  [["journal"   #{"daily-notes" "daily-note" "daily" "journal" "diary"}]
   ["meeting"   #{"meeting" "meetings" "meeting-notes" "meeting-note"
                  "standup" "1on1" "1-on-1" "retro" "retrospective"}]
   ["project"   #{"project" "project-plan" "roadmap" "sprint"}]
   ["idea"      #{"idea" "ideas" "brainstorm" "concept" "proposal"}]
   ["reference" #{"reference" "howto" "how-to" "guide" "cheatsheet"
                  "cheat-sheet" "documentation" "docs"}]])

(def ^:private type-signals
  [["journal"   #{"daily" "journal" "daily-note" "daily-notes"}]
   ["meeting"   #{"meeting" "meetings"}]
   ["project"   #{"project"}]
   ["idea"      #{"idea"}]
   ["reference" #{"reference" "howto" "guide"}]])

(def ^:private path-signals
  [["journal"   #{"daily notes" "daily" "journal"}]
   ["meeting"   #{"meetings" "meeting notes"}]
   ["project"   #{"projects"}]])

(defn detect-classification-from-frontmatter
  "Detect classification from frontmatter signals and file path.
   Returns {:classification string :confidence number :signal string} if a
   strong signal is found (1.0 for tag/type/cssclass, 0.9 for path), nil otherwise."
  [metadata object-key]
  (let [tags (->> (get metadata :tags [])
                  (map (comp str/lower-case str/trim str)))
        fm-type (some-> (get metadata :type) str str/trim str/lower-case)
        cssclass (some-> (get metadata :cssclass) str str/trim str/lower-case)
        cssclasses (->> (get metadata :cssclasses [])
                        (map (comp str/lower-case str/trim str)))
        all-classes (cond-> #{}
                      cssclass (conj cssclass)
                      (seq cssclasses) (into cssclasses))
        path-lower (str/lower-case (or object-key ""))]

    ;; Check tags first (strongest signal)
    (or (some (fn [[classification signal-tags]]
                (when-let [match (first (filter signal-tags tags))]
                  {:classification classification
                   :confidence 1.0
                   :signal (str "tag:" match)}))
              tag-signals)

        ;; Check frontmatter type field
        (some (fn [[classification signal-types]]
                (when (and fm-type (signal-types fm-type))
                  {:classification classification
                   :confidence 1.0
                   :signal (str "type:" fm-type)}))
              type-signals)

        ;; Check cssclass/cssclasses
        (some (fn [[classification signal-tags]]
                (when-let [match (first (filter signal-tags all-classes))]
                  {:classification classification
                   :confidence 1.0
                   :signal (str "cssclass:" match)}))
              tag-signals)

        ;; Check file path segments (match at start or after /)
        (some (fn [[classification path-parts]]
                (when-let [match (first (filter #(re-find (re-pattern (str "(?:^|/)" (java.util.regex.Pattern/quote %) "/")) path-lower) path-parts))]
                  {:classification classification
                   :confidence 0.9
                   :signal (str "path:" match "/")}))
              path-signals))))

(defn classify-document
  "Classify a markdown document using Bedrock"
  [bucket-name object-key]
  (println "Processing document:" object-key)

  ;; Fetch existing record once for override check and date preservation
  (let [existing-record (ddb/get-item ddb-table {:PK object-key :SK "METADATA"})]

    ;; Check for classification override before reclassifying
    (when (:classification_override existing-record)
      (println "Skipping" object-key "- classification override is set")
      (throw (ex-info "Classification override set"
                      {:object-key object-key
                       :classification (:classification existing-record)
                       :skipped true})))

    ;; Check if document still exists in S3
    (when-not (s3/object-exists? bucket-name object-key)
      (println "Document no longer exists in S3:" object-key)
      (throw (ex-info "Document not found in S3"
                      {:object-key object-key
                       :not-found true})))

    ;; Get document content
    (let [content (s3/get-object bucket-name object-key)]

      (when (empty? content)
        (println "Warning: Empty content for" object-key)
        (throw (ex-info "Empty document" {:object-key object-key})))

      ;; Parse metadata
      (let [metadata (md/parse-markdown-metadata content)

            ;; Check for deterministic frontmatter signals before calling Bedrock
            fm-signal (detect-classification-from-frontmatter metadata object-key)

            result (if fm-signal
                     (do (println "Frontmatter signal detected for" object-key
                                  ":" (:signal fm-signal)
                                  "→" (:classification fm-signal))
                         fm-signal)
                     (bedrock/classify-document bedrock-model content metadata))

            classification (:classification result)
            confidence (:confidence result)

            _ (println "Classified" object-key "as:" classification
                       "confidence:" confidence)

            ;; Add classification and confidence to metadata
            ;; Preserve existing created/modified dates from extract_metadata
            metadata (assoc metadata
                           :classification classification
                           :classification_confidence confidence
                           :s3_key object-key)
            metadata (cond-> metadata
                       (:created existing-record)  (assoc :created (:created existing-record))
                       (:modified existing-record) (assoc :modified (:modified existing-record))
                       (not (:modified existing-record)) (assoc :modified (md/now-iso)))]

        ;; Store classification in DynamoDB
        (ddb/put-item ddb-table
                      (assoc metadata
                             :PK object-key
                             :SK "METADATA"
                             :document_path object-key))

        {:classification classification
         :confidence confidence
         :title (:title metadata)}))))

(defn handler
  "Lambda handler for bblf runtime - receives raw HTTP request from Lambda Runtime API"
  [request]
  (try
    ;; bblf.runtime passes the raw HTTP response from Lambda Runtime API
    (let [event (json/parse-string (:body request) true)]
      (println "Received event:" (json/generate-string event))

      ;; Extract S3 object details from EventBridge event
      (let [detail (get event :detail {})
            bucket-name (get-in detail [:bucket :name])
            object-key (get-in detail [:object :key])]

        ;; Validate event
        (when (or (nil? bucket-name) (nil? object-key))
          (println "Error: Missing bucket name or object key in event")
          (throw (ex-info "Invalid event format" {:event event})))

        ;; Check if should skip
        (if (should-skip? object-key)
          (do
            (println "Skipping file:" object-key)
            {:statusCode 200
             :body (json/generate-string {:message "Skipped file"
                                          :object-key object-key})})

          ;; Classify the document
          (let [result (classify-document bucket-name object-key)]
            {:statusCode 200
             :body (json/generate-string {:document object-key
                                          :classification (:classification result)
                                          :confidence (:confidence result)})}))))

    (catch Exception e
      (let [data (ex-data e)]
        (cond
          ;; Override skip is not an error
          (:skipped data)
          {:statusCode 200
           :body (json/generate-string {:document (:object-key data)
                                        :classification (:classification data)
                                        :skipped true})}

          ;; Document deleted from S3 - not an error
          (:not-found data)
          {:statusCode 200
           :body (json/generate-string {:document (:object-key data)
                                        :not_found true
                                        :message "Document no longer exists in S3"})}

          :else
          (do
            (println "Error processing document:" (ex-message e))
            (.printStackTrace e)
            {:statusCode 500
             :body (json/generate-string {:error (ex-message e)})}))))))

;; For local testing
(defn -main []
  (let [test-event {:detail {:bucket {:name s3-bucket}
                             :object {:key "test.md"}}}]
    (println "Running test with event:" test-event)
    (println "Result:" (handler test-event))))


(comment 
  (-main))
