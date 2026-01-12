(ns markdown.utils
  "Markdown parsing and manipulation utilities for PKM agent"
  (:require [clj-yaml.core :as yaml]
            [clojure.string :as str]
            [java-time.api :as time]))

(defn extract-frontmatter
  "Extract YAML frontmatter from markdown content.
   Returns [frontmatter-map content-without-frontmatter]"
  [content]
  (let [pattern #"(?s)^---\s*\n(.*?)\n---\s*\n(.*)$"
        match (re-matches pattern content)]
    (if match
      (try
        (let [frontmatter-str (nth match 1)
              body (nth match 2)
              frontmatter (yaml/parse-string frontmatter-str)]
          [frontmatter body])
        (catch Exception e
          (println "Error parsing YAML frontmatter:" (.getMessage e))
          [nil content]))
      [nil content])))

(defn extract-wikilinks
  "Extract wikilinks from markdown content.
   Matches [[link]] and [[link|display]] patterns"
  [content]
  (let [pattern #"\[\[([^\]|]+)(?:\|[^\]]+)?\]\]"
        matches (re-seq pattern content)]
    (->> matches
         (map second)
         (map str/trim)
         distinct
         vec)))

(defn extract-tags
  "Extract tags from frontmatter and inline hashtags"
  [content frontmatter]
  (let [tags (atom #{})

        ;; Extract from frontmatter
        _ (when frontmatter
            (when-let [fm-tags (:tags frontmatter)]
              (cond
                (vector? fm-tags) (swap! tags into (map str fm-tags))
                (string? fm-tags) (swap! tags into (str/split fm-tags #",\s*")))))

        ;; Extract inline hashtags
        hashtag-pattern #"(?:^|\s)#([a-zA-Z0-9_-]+)"
        inline-tags (map second (re-seq hashtag-pattern content))
        _ (swap! tags into inline-tags)]

    (vec @tags)))

(defn extract-title
  "Extract document title from frontmatter or first H1 heading"
  [content frontmatter]
  (or
   ;; Check frontmatter first
   (when frontmatter
     (some-> (:title frontmatter) str str/trim))

   ;; Look for first H1 heading
   (when-let [match (re-find #"(?m)^#\s+(.+)$" content)]
     (str/trim (second match)))

   ;; Default
   "Untitled"))

(defn create-frontmatter
  "Create YAML frontmatter from metadata map"
  [metadata]
  (str "---\n"
       (yaml/generate-string metadata :dumper-options {:flow-style :block})
       "---\n"))

(defn create-summary-document
  "Create a formatted daily summary markdown document"
  [date summary-content source-docs doc-count]
  (let [frontmatter {:generated (str (time/instant))
                     :agent "summarization"
                     :period "daily"
                     :source_docs doc-count
                     :tags ["agent-generated" "summary"]}
        doc-links (str/join "\n" (map #(str "- [[" % "]]") source-docs))]
    (str (create-frontmatter frontmatter)
         "# Daily Summary - " date "\n\n"
         summary-content "\n\n"
         "## Source Documents\n"
         doc-links "\n\n"
         "---\n"
         "*Generated automatically by PKM agent*\n")))

(defn create-weekly-report-document
  "Create a formatted weekly report markdown document"
  [week report-content source-count]
  (let [frontmatter {:generated (str (time/instant))
                     :agent "reporting"
                     :period "weekly"
                     :week week
                     :source_docs source-count
                     :tags ["agent-generated" "weekly-report"]}]
    (str (create-frontmatter frontmatter)
         "# Weekly Report - " week "\n\n"
         report-content "\n\n"
         "---\n"
         "*Generated automatically by PKM agent*\n")))

(defn create-entity-page
  "Create a formatted entity page markdown document"
  [entity-name entity-type mentions]
  (let [frontmatter {:type entity-type
                     :mentioned_in (mapv :path mentions)
                     :last_updated (str (time/instant))}
        mentions-text (str/join "\n"
                               (map #(str "- [[" (:path %) "]] - " (get % :context ""))
                                    mentions))]
    (str (create-frontmatter frontmatter)
         "# " entity-name "\n\n"
         "## Mentions\n"
         mentions-text "\n")))

(defn create-classification-index
  "Create a formatted classification index markdown document"
  [classifications]
  (let [frontmatter {:generated (str (time/instant))
                     :tags ["index" "agent-generated"]}
        classification-order ["meeting" "idea" "reference" "journal" "project"]
        sections (for [classification classification-order
                       :let [docs (get classifications classification)]
                       :when (seq docs)]
                   (let [doc-links (str/join "\n"
                                            (map #(str "- [[" % "]]")
                                                 (sort docs)))]
                     (str "## " (str/capitalize classification) "\n" doc-links)))
        sections-text (str/join "\n\n" sections)]
    (str (create-frontmatter frontmatter)
         "# Document Classifications\n\n"
         sections-text "\n")))

(defn sanitize-filename
  "Sanitize a string for use as a filename"
  [name]
  (-> name
      (str/replace #"\s+" "-")
      (str/replace #"[^\w\-.]" "")
      str/lower-case
      (str/replace #"^-+|-+$" "")))

(defn get-week-string
  "Get ISO week string for a date in YYYY-Www format"
  [date]
  (let [year (time/as date :year)
        week (time/as date :week-of-week-based-year)]
    (format "%d-W%02d" year week)))

(defn parse-markdown-metadata
  "Parse markdown content and extract all metadata"
  [content]
  (let [[frontmatter body] (extract-frontmatter content)
        tags (extract-tags body frontmatter)
        title (extract-title body frontmatter)
        wikilinks (extract-wikilinks body)

        metadata {:title title
                  :tags tags
                  :links_to wikilinks
                  :has_frontmatter (some? frontmatter)}

        ;; Include specific frontmatter fields
        metadata (if frontmatter
                   (merge metadata
                          (select-keys frontmatter [:date :created :modified])
                          ;; Include other frontmatter fields
                          (apply dissoc frontmatter
                                 [:title :tags :date :created :modified]))
                   metadata)]

    metadata))
