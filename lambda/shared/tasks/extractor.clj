(ns tasks.extractor
  "Pure-function task extraction from markdown content.
   Detects checkboxes, TODO/ACTION/FIXME markers, and AI-assisted implicit tasks."
  (:require [aws.bedrock :as bedrock]
            [cheshire.core :as json]
            [clojure.string :as str]))

;; =============================================================================
;; Task ID generation
;; =============================================================================

(defn generate-task-id
  "Generate a deterministic task ID from document path, line number, and description.
   Uses hash to create a stable identifier for deduplication across reprocessing."
  [doc-path line-number description]
  (let [desc-prefix (subs description 0 (min 80 (count description)))
        input (str doc-path "|" line-number "|" desc-prefix)]
    (str "t-" (format "%08x" (Math/abs (hash input))))))

;; =============================================================================
;; Date extraction
;; =============================================================================

(def ^:private date-pattern
  "Match ISO-like dates (YYYY-MM-DD) in task text"
  #"\b(\d{4}-\d{2}-\d{2})\b")

(defn- extract-due-date
  "Extract a potential due date from task text. Looks for date patterns
   preceded by keywords like 'by', 'due', 'before', 'deadline'."
  [text]
  (when-let [match (re-find #"(?i)(?:by|due|before|deadline)\s+(\d{4}-\d{2}-\d{2})" text)]
    (second match)))

;; =============================================================================
;; Priority detection
;; =============================================================================

(defn- detect-priority
  "Detect priority from task text based on markers and keywords."
  [text]
  (let [lower (str/lower-case text)]
    (cond
      (or (re-find #"(?i)\b(urgent|critical|asap|immediately)\b" lower)
          (re-find #"!!!" lower)
          (re-find #"\[!!\]" text)) "high"
      (or (re-find #"(?i)\b(important|priority|soon)\b" lower)
          (re-find #"!!" lower)) "medium"
      (or (re-find #"(?i)\b(low priority|nice to have|someday|maybe)\b" lower)
          (re-find #"(?i)\blow\b" lower)) "low"
      :else nil)))

;; =============================================================================
;; Checkbox extraction
;; =============================================================================

(def ^:private checkbox-pattern
  "Match markdown checkboxes: - [ ] or - [x] (case-insensitive x)"
  #"^(\s*[-*+]\s+)\[([ xX])\]\s+(.+)$")

(defn extract-checkbox-tasks
  "Extract tasks from markdown checkboxes (- [ ] and - [x] patterns).
   Returns a vector of task maps with :description, :status, :line_number, :marker, :context."
  [content]
  (let [lines (str/split-lines content)]
    (->> lines
         (map-indexed (fn [idx line]
                        (when-let [match (re-matches checkbox-pattern line)]
                          (let [checked? (not= " " (nth match 2))
                                description (str/trim (nth match 3))]
                            {:description description
                             :status (if checked? "completed" "open")
                             :source "pattern"
                             :marker "checkbox"
                             :line_number (inc idx)
                             :due_date (extract-due-date description)
                             :priority (detect-priority description)
                             :context (str/trim line)}))))
         (remove nil?)
         vec)))

;; =============================================================================
;; Marker extraction (TODO, ACTION, FIXME)
;; =============================================================================

(def ^:private marker-patterns
  "Patterns for TODO/ACTION/FIXME markers with the text that follows"
  [[:todo   #"(?i)\bTODO\s*:?\s+(.+)"]
   [:action #"(?i)\bACTION\s*:?\s+(.+)"]
   [:fixme  #"(?i)\bFIXME\s*:?\s+(.+)"]])

(defn extract-marker-tasks
  "Extract tasks from TODO:, ACTION:, and FIXME: markers in text.
   Returns a vector of task maps."
  [content]
  (let [lines (str/split-lines content)]
    (->> lines
         (map-indexed
          (fn [idx line]
            ;; Skip lines that are checkboxes (avoid double extraction)
            (when-not (re-matches checkbox-pattern line)
              (some (fn [[marker-type pattern]]
                      (when-let [match (re-find pattern line)]
                        (let [description (str/trim (second match))]
                          {:description description
                           :status "open"
                           :source "pattern"
                           :marker (name marker-type)
                           :line_number (inc idx)
                           :due_date (extract-due-date description)
                           :priority (detect-priority description)
                           :context (str/trim line)})))
                    marker-patterns))))
         (remove nil?)
         vec)))

;; =============================================================================
;; Combined pattern extraction
;; =============================================================================

(defn extract-pattern-tasks
  "Extract all pattern-based tasks (checkboxes + markers) from content."
  [content]
  (into (extract-checkbox-tasks content)
        (extract-marker-tasks content)))

;; =============================================================================
;; AI-assisted extraction
;; =============================================================================

(def ^:private task-extraction-system-prompt
  "You are an expert at identifying actionable tasks in documents.
Extract implicit tasks, action items, and commitments from the text.

Only extract items that are clearly actionable — things someone needs to do.
Do NOT extract observations, descriptions, or completed work.
Do NOT extract items that are already marked as checkboxes (- [ ]) or TODO/ACTION/FIXME markers.

Return a JSON array of objects, each with:
- \"description\": concise task description (imperative form, e.g. \"Review the proposal\")
- \"due_date\": ISO date string if mentioned, null otherwise
- \"priority\": \"high\", \"medium\", \"low\", or null
- \"line_number\": approximate line number in the document, or null

Return ONLY valid JSON array, no additional text. If no tasks found, return [].")

(defn- strip-markdown-fences
  "Strip markdown code fences from LLM response text"
  [text]
  (-> text
      str/trim
      (str/replace #"^```[a-z]*\s*\n?" "")
      (str/replace #"\n?\s*```$" "")
      str/trim))

(defn extract-ai-tasks
  "Use Bedrock to extract implicit tasks from document content.
   Only call for meeting/project documents to control costs."
  [model-id content]
  (try
    (let [prompt (str "Extract actionable tasks from this document:\n\n" content)
          response (bedrock/invoke-model model-id prompt
                                         {:max-tokens 2000
                                          :temperature 0.3
                                          :system task-extraction-system-prompt})
          text (bedrock/extract-text response)
          cleaned (strip-markdown-fences text)
          parsed (json/parse-string cleaned true)]
      (if (sequential? parsed)
        (->> parsed
             (mapv (fn [task]
                     {:description (or (:description task) "")
                      :status "open"
                      :source "ai"
                      :marker "implicit"
                      :line_number (:line_number task)
                      :due_date (:due_date task)
                      :priority (:priority task)
                      :context nil}))
             (filterv #(not (str/blank? (:description %)))))
        []))
    (catch Exception e
      (println "Error in AI task extraction:" (ex-message e))
      [])))

;; =============================================================================
;; Task merging / deduplication
;; =============================================================================

(defn- tasks-overlap?
  "Check if two tasks are likely referring to the same action item.
   Compares by line number proximity and description similarity."
  [pattern-task ai-task]
  (let [p-line (:line_number pattern-task)
        a-line (:line_number ai-task)
        p-desc (str/lower-case (:description pattern-task))
        a-desc (str/lower-case (:description ai-task))]
    (or
     ;; Same line
     (and p-line a-line (= p-line a-line))
     ;; Close lines and description contains pattern task description
     (and p-line a-line
          (<= (Math/abs (- p-line a-line)) 2)
          (or (str/includes? a-desc p-desc)
              (str/includes? p-desc a-desc))))))

(defn merge-tasks
  "Merge pattern-extracted and AI-extracted tasks, removing AI duplicates
   that overlap with pattern tasks (pattern tasks take priority)."
  [pattern-tasks ai-tasks]
  (let [non-duplicate-ai (remove (fn [ai-task]
                                   (some #(tasks-overlap? % ai-task)
                                         pattern-tasks))
                                 ai-tasks)]
    (into (vec pattern-tasks) non-duplicate-ai)))
