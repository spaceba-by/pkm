(ns command.parser
  "Detects and parses @sal and @workflow commands in markdown document content"
  (:require [clojure.string]))

(defn- strip-code-blocks
  "Remove fenced code blocks from content to avoid matching commands inside them,
   while preserving line count so line numbers stay aligned with the original content."
  [content]
  (clojure.string/replace
   content
   #"(?s)```.*?```"
   (fn [match]
     ;; Replacing the block with the same number of newlines it contained
     ;; keeps every following line at its original line number.
     (apply str (repeat (count (re-seq #"\n" match)) "\n")))))

(defn parse-commands
  "Parse @sal commands from markdown content.
   Returns a vector of maps with :command and :line-number keys.
   Commands inside fenced code blocks are ignored."
  [content]
  (when (and content (clojure.string/includes? content "@sal"))
    (let [cleaned (strip-code-blocks content)
          lines (clojure.string/split-lines cleaned)]
      (vec
       (keep-indexed
        (fn [idx line]
          (when-let [match (re-matches #"^@sal\s+(.+)$" (clojure.string/trim line))]
            {:command (second match)
             :line-number (inc idx)}))
        lines)))))

(defn has-commands?
  "Returns true if the content contains any @sal commands outside code blocks"
  [content]
  (boolean (seq (parse-commands content))))

(def ^:private workflow-command-pattern
  "Matches `@workflow:<name> [args]` on its own line. The marker is
   case-sensitive like @sal; the name is folded to lower case."
  #"^@workflow:([A-Za-z0-9][A-Za-z0-9-]*)(?:\s+(.*))?$")

(defn parse-workflow-commands
  "Parse @workflow:<name> [args] commands from markdown content.
   Returns a vector of maps with :name (lower-cased slug), :args (string,
   possibly empty) and :line-number keys. Commands inside fenced code blocks
   are ignored. Returns nil when the content has no @workflow: marker."
  [content]
  (when (and content (clojure.string/includes? content "@workflow:"))
    (let [cleaned (strip-code-blocks content)
          lines (clojure.string/split-lines cleaned)]
      (vec
       (keep-indexed
        (fn [idx line]
          (when-let [match (re-matches workflow-command-pattern (clojure.string/trim line))]
            {:name (clojure.string/lower-case (nth match 1))
             :args (clojure.string/trim (or (nth match 2) ""))
             :line-number (inc idx)}))
        lines)))))

(defn has-workflow-commands?
  "Returns true if the content contains any @workflow: commands outside code blocks"
  [content]
  (boolean (seq (parse-workflow-commands content))))
