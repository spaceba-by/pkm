(ns search.chunker
  "Splits Obsidian markdown documents into chunks by heading structure.
   Each chunk includes the section heading, text content, and document path."
  (:require [clojure.string :as str]))

(defn- strip-frontmatter
  "Remove YAML frontmatter from markdown content"
  [content]
  (let [pattern #"(?s)^---\s*\n.*?\n---\s*\n(.*)$"
        match (re-matches pattern content)]
    (if match
      (second match)
      content)))

(defn- heading-level
  "Return heading level (1-6) for a line, or nil if not a heading"
  [line]
  (when-let [match (re-matches #"^(#{1,6})\s+.*" line)]
    (count (second match))))

(defn- heading-text
  "Extract heading text from a heading line"
  [line]
  (when-let [match (re-matches #"^#{1,6}\s+(.+)$" line)]
    (str/trim (second match))))

(defn chunk-document
  "Split a markdown document into chunks by heading structure.
   Returns a vector of maps:
   [{:path \"docs/note.md\"
     :chunk_id 0
     :heading \"Introduction\"
     :content \"Text content of section...\"}]

   Chunks are split at heading boundaries (any level).
   Content before the first heading becomes chunk 0 with heading from the document title.
   Empty chunks (no meaningful content) are filtered out."
  [path content & {:keys [title] :or {title nil}}]
  (let [body (strip-frontmatter content)
        lines (str/split-lines body)
        ;; Walk through lines, splitting at headings
        segments (loop [remaining lines
                        current-heading (or title "")
                        current-lines []
                        result []]
                   (if (empty? remaining)
                     ;; Flush final segment
                     (if (seq current-lines)
                       (conj result {:heading current-heading
                                     :lines current-lines})
                       result)
                     (let [line (first remaining)
                           level (heading-level line)]
                       (if level
                         ;; New heading: flush current segment, start new one
                         (let [flushed (if (seq current-lines)
                                         (conj result {:heading current-heading
                                                       :lines current-lines})
                                         result)]
                           (recur (rest remaining)
                                  (heading-text line)
                                  []
                                  flushed))
                         ;; Regular line: add to current segment
                         (recur (rest remaining)
                                current-heading
                                (conj current-lines line)
                                result)))))]
    (->> segments
         (map-indexed
          (fn [idx segment]
            {:path path
             :chunk_id idx
             :heading (:heading segment)
             :content (str/trim (str/join "\n" (:lines segment)))}))
         (filter #(not (str/blank? (:content %))))
         vec)))
