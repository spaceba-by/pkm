(ns workflow.engine
  "Template interpolation and context building for custom agent workflows.

   Templates use {{path.to.value}} placeholders resolved against a context map
   built by `build-context`. Unresolved placeholders render as empty strings.
   Also owns the output path rules: every rendered output path must resolve
   under `_agent/`, which is excluded from the processing pipeline and so can
   never overwrite a user note or re-trigger a workflow."
  (:require [clojure.string :as str]
            [cheshire.core :as json]
            [markdown.utils :as md])
  (:import [java.time Instant ZoneOffset]
           [java.time.format DateTimeFormatter]
           [java.time.temporal ChronoUnit]))

;; =============================================================================
;; Limits and constants
;; =============================================================================

(def max-document-chars
  "Maximum characters of a single document's content placed in a template"
  60000)

(def max-documents-chars
  "Maximum characters of the combined document-set content placed in a template"
  120000)

(def output-root
  "Every workflow output path must live under this prefix"
  "_agent/")

(def default-output-path
  "Output path template used when a workflow does not set one"
  "_agent/workflows/{{workflow.name}}/{{now.date}}-{{run.id}}.md")

(def known-roots
  "Top-level context names a template may reference"
  #{"document" "entity" "documents" "command" "workflow" "run" "now"})

;; =============================================================================
;; Template parsing and rendering
;; =============================================================================

(def ^:private var-pattern
  "Matches {{ path.to.value }}; path segments allow letters, digits, _ and -"
  #"\{\{\s*([A-Za-z0-9_\-]+(?:\.[A-Za-z0-9_\-]+)*)\s*\}\}")

(defn template-variables
  "Return the distinct variable paths referenced by a template, in order of
   first appearance. A nil or blank template has no variables."
  [template]
  (if (str/blank? template)
    []
    (->> (re-seq var-pattern template)
         (map second)
         distinct
         vec)))

(defn validate-template
  "Validate a template string. Returns a vector of error messages; empty when
   valid. Errors cover malformed {{ }} expressions and unknown variable roots."
  [template]
  (if (str/blank? template)
    []
    (let [stripped (str/replace template var-pattern "")
          malformed (when (or (str/includes? stripped "{{")
                              (str/includes? stripped "}}"))
                      "Malformed template expression: unbalanced or invalid {{ }}")
          unknown (->> (template-variables template)
                       (map #(first (str/split % #"\.")))
                       (remove known-roots)
                       distinct
                       (map #(str "Unknown template variable root: " %)))]
      (vec (remove nil? (cons malformed unknown))))))

(defn render-value
  "Render a context value as template text. Strings pass through, sequences
   join with commas, sets join sorted, maps render as JSON, nil renders empty."
  [v]
  (cond
    (nil? v) ""
    (string? v) v
    (sequential? v) (str/join ", " (map render-value v))
    (set? v) (str/join ", " (sort (map render-value v)))
    (map? v) (json/generate-string v)
    :else (str v)))

(defn- lookup-step
  "Look up one path segment in a map, trying keyword then string keys"
  [m segment]
  (when (map? m)
    (if (contains? m (keyword segment))
      (get m (keyword segment))
      (get m segment))))

(defn lookup
  "Resolve a dotted path such as \"document.frontmatter.status\" in ctx.
   Returns nil when any segment is missing."
  [ctx path]
  (reduce (fn [m segment]
            (if (nil? m)
              (reduced nil)
              (lookup-step m segment)))
          ctx
          (str/split path #"\.")))

(defn render
  "Render a template against ctx. Unresolvable variables become empty strings
   and are logged. A nil template renders as an empty string."
  [template ctx]
  (if (nil? template)
    ""
    (str/replace template var-pattern
                 (fn [[_ path]]
                   (let [v (lookup ctx path)]
                     (when (nil? v)
                       (println "Warning: unresolved template variable" path))
                     (render-value v))))))

;; =============================================================================
;; Context building
;; =============================================================================

(defn truncate
  "Truncate s to at most n characters, appending a marker when cut"
  [s n]
  (let [s (or s "")]
    (if (> (count s) n)
      (str (subs s 0 n) "\n\n[... truncated ...]")
      s)))

(defn title-from-path
  "Derive a title from an S3 key: last path segment without the .md suffix"
  [path]
  (-> (or path "")
      (str/split #"/")
      last
      (or "")
      (str/replace #"\.md$" "")))

(defn document-context
  "Build the `document` context from a METADATA record and the raw content.
   metadata may be nil for documents the pipeline has not processed yet."
  [path metadata content]
  (let [content (or content "")
        [frontmatter body] (md/extract-frontmatter content)
        title (or (some-> (:title metadata) str not-empty)
                  (not-empty (title-from-path path))
                  "Untitled")]
    {:path path
     :title title
     :content (truncate content max-document-chars)
     :body (truncate body max-document-chars)
     :tags (vec (or (:tags metadata) []))
     :classification (:classification metadata)
     :created (:created metadata)
     :modified (:modified metadata)
     :frontmatter (or frontmatter {})}))

(defn entity-context
  "Build the `entity` context from the METADATA entities map"
  [entities]
  (let [get-list (fn [k] (vec (or (get entities k) (get entities (name k)) [])))
        people (get-list :people)
        organizations (get-list :organizations)
        concepts (get-list :concepts)
        locations (get-list :locations)]
    {:people people
     :organizations organizations
     :concepts concepts
     :locations locations
     :names (vec (distinct (concat people organizations concepts locations)))}))

(defn documents-context
  "Build the `documents` context for a set of documents, each a map with
   :title, :path and :body. The combined content block is truncated."
  [docs]
  (let [docs (vec docs)]
    {:count (count docs)
     :list (str/join "\n" (map #(str "- " (:title %) " (" (:path %) ")") docs))
     :content (truncate (str/join "\n\n---\n\n"
                                  (map #(str "## " (:title %) "\n\n" (or (:body %) "")) docs))
                        max-documents-chars)}))

(defn command-context
  "Build the `command` context from a parsed @workflow command"
  [{:keys [name args]}]
  {:name name
   :args (or args "")
   :text (str "@workflow:" name (when-not (str/blank? args) (str " " args)))})

(defn now-context
  "Build the `now` context from an Instant (UTC)"
  [^Instant instant]
  (let [utc (.atZone instant ZoneOffset/UTC)]
    {:iso (str (.truncatedTo instant ChronoUnit/SECONDS))
     :date (.format utc DateTimeFormatter/ISO_LOCAL_DATE)
     :weekday (str/lower-case (str (.getDayOfWeek utc)))}))

(defn build-context
  "Assemble the full template context.
   Options:
     :workflow  - workflow definition (needs :workflow_id and :name)
     :run-id    - run identifier
     :document  - {:path :metadata :content} for single-document triggers
     :documents - seq of {:title :path :body} for set triggers
     :command   - {:name :args} for command triggers
     :now       - Instant (defaults to now)"
  [{:keys [workflow run-id document documents command now]}]
  (let [metadata (:metadata document)]
    (cond-> {:workflow {:id (:workflow_id workflow)
                        :name (:name workflow)}
             :run {:id run-id}
             :now (now-context (or now (Instant/now)))}
      document (assoc :document (document-context (:path document) metadata (:content document))
                      :entity (entity-context (:entities metadata)))
      documents (assoc :documents (documents-context documents))
      command (assoc :command (command-context command)))))

;; =============================================================================
;; Output paths and documents
;; =============================================================================

(defn- sanitize-segment
  "Replace characters that are unsafe in S3 keys or Obsidian file names"
  [segment]
  (-> segment
      (str/replace #"[\p{Cntrl}#?%*:|\"<>\\]" "-")
      str/trim))

(defn normalize-output-path
  "Normalize a rendered output path and enforce the `_agent/` boundary.
   Removes leading slashes and `.` segments, collapses repeated slashes,
   sanitizes each segment and appends .md when missing. Throws ex-info with
   {:type :validation} when the path contains a `..` segment, does not
   resolve under `_agent/`, or has no file name beneath it."
  [rendered]
  (let [raw-segments (str/split (str/replace (or rendered "") "\\" "/") #"/")
        _ (when (some #(= ".." %) raw-segments)
            (throw (ex-info (str "Workflow output path must not contain '..': " rendered)
                            {:type :validation :path rendered})))
        segments (->> raw-segments
                      (map sanitize-segment)
                      (remove #(or (str/blank? %) (= "." %)))
                      vec)
        path (str/join "/" segments)
        path (if (str/ends-with? path ".md") path (str path ".md"))]
    (when (or (< (count segments) 2)
              (not (str/starts-with? path output-root)))
      (throw (ex-info (str "Workflow output path must be under " output-root ": " rendered)
                      {:type :validation :path rendered})))
    path))

(defn output-path-template-allowed?
  "Static check used by the API: the template must start with `_agent/`
   literally, so no variable can move the output elsewhere."
  [template]
  (and (string? template)
       (str/starts-with? (str/triml template) output-root)))

(defn- yaml-quote
  "Quote a string for a single-line YAML scalar"
  [s]
  (str "\"" (-> (str s)
                (str/replace "\\" "\\\\")
                (str/replace "\"" "\\\"")
                (str/replace "\n" " "))
       "\""))

(defn render-output-document
  "Build the markdown written for the s3 destination: a frontmatter header
   describing the run, followed by the model output."
  [{:keys [workflow-name run-id trigger document-path model-id generated-at]} result]
  (str "---\n"
       "workflow: " (yaml-quote workflow-name) "\n"
       "run_id: " run-id "\n"
       "trigger: " trigger "\n"
       (when document-path (str "source_document: " (yaml-quote document-path) "\n"))
       "model: " model-id "\n"
       "generated_at: " generated-at "\n"
       "tags: [agent-generated, workflow]\n"
       "---\n\n"
       (or result "")
       "\n"))
