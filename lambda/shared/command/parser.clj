(ns command.parser
  "Detects and parses @sal commands in markdown document content")

(defn- strip-code-blocks
  "Remove fenced code blocks from content to avoid matching commands inside them,
   while preserving line count so line numbers stay aligned with the original content."
  [content]
  (clojure.string/replace
   content
   #"(?s)```.*?```"
   (fn [match]
     (let [newline-count (count (re-seq #"\n" match))
           ;; A block with N newlines spans N+1 lines; replace with that many newlines
           placeholder-newlines (inc newline-count)]
       (apply str (repeat placeholder-newlines "\n"))))))

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
