(ns shared.classification-test
  "Tests for classification prompt parsing, override logic, bulk filtering,
   and frontmatter signal detection"
  (:require [clojure.test :refer [deftest is testing]]
            [cheshire.core :as json]
            [clojure.string :as str]))

;; =============================================================================
;; Classification response parsing tests
;; (Duplicated from bedrock.clj for the same reason as handlers_test.clj)
;; =============================================================================

(def valid-classifications
  #{"meeting" "idea" "reference" "journal" "project"})

(defn- strip-markdown-fences
  "Strip markdown code fences from LLM response text"
  [text]
  (-> text
      str/trim
      (str/replace #"^```[a-z]*\s*\n?" "")
      (str/replace #"\n?\s*```$" "")
      str/trim))

(defn parse-classification-response
  "Parse classification JSON response, matching bedrock/classify-document logic"
  [text]
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
    (catch Exception _
      {:classification "reference"
       :confidence 0.0})))

(deftest parse-classification-response-test
  (testing "Parses valid JSON response"
    (let [result (parse-classification-response
                   "{\"classification\": \"meeting\", \"confidence\": 0.95}")]
      (is (= "meeting" (:classification result)))
      (is (= 0.95 (:confidence result)))))

  (testing "Parses response with whitespace and mixed case"
    (let [result (parse-classification-response
                   "{\"classification\": \"  Meeting  \", \"confidence\": 0.8}")]
      (is (= "meeting" (:classification result)))
      (is (= 0.8 (:confidence result)))))

  (testing "Falls back to reference for invalid classification"
    (let [result (parse-classification-response
                   "{\"classification\": \"unknown\", \"confidence\": 0.5}")]
      (is (= "reference" (:classification result)))
      (is (= 0.0 (:confidence result)))))

  (testing "Falls back to reference for empty classification"
    (let [result (parse-classification-response
                   "{\"classification\": \"\", \"confidence\": 0.5}")]
      (is (= "reference" (:classification result)))
      (is (= 0.0 (:confidence result)))))

  (testing "Handles missing confidence field"
    (let [result (parse-classification-response
                   "{\"classification\": \"idea\"}")]
      (is (= "idea" (:classification result)))
      (is (= 0.0 (:confidence result)))))

  (testing "Parses JSON wrapped in markdown code fences"
    (let [result (parse-classification-response
                   "```json\n{\"classification\": \"meeting\", \"confidence\": 0.85}\n```")]
      (is (= "meeting" (:classification result)))
      (is (= 0.85 (:confidence result)))))

  (testing "Parses JSON wrapped in plain code fences"
    (let [result (parse-classification-response
                   "```\n{\"classification\": \"idea\", \"confidence\": 0.7}\n```")]
      (is (= "idea" (:classification result)))
      (is (= 0.7 (:confidence result)))))

  (testing "Falls back to reference on completely invalid input"
    (let [result (parse-classification-response "nonsense text here")]
      (is (= "reference" (:classification result)))
      (is (= 0.0 (:confidence result)))))

  (testing "All valid classification types are accepted"
    (doseq [cls ["meeting" "idea" "reference" "journal" "project"]]
      (let [json-str (json/generate-string {:classification cls :confidence 0.9})
            result (parse-classification-response json-str)]
        (is (= cls (:classification result))
            (str cls " should be accepted"))))))

;; =============================================================================
;; Classification override logic tests
;; =============================================================================

(deftest override-flag-test
  (testing "Document with classification_override true should be skipped"
    (let [doc {:PK "notes/test.md"
               :SK "METADATA"
               :classification "meeting"
               :classification_override true}]
      (is (true? (:classification_override doc)))))

  (testing "Document without classification_override should not be skipped"
    (let [doc {:PK "notes/test.md"
               :SK "METADATA"
               :classification "meeting"}]
      (is (nil? (:classification_override doc)))))

  (testing "Document with classification_override false should not be skipped"
    (let [doc {:PK "notes/test.md"
               :SK "METADATA"
               :classification "meeting"
               :classification_override false}]
      (is (false? (:classification_override doc))))))

;; =============================================================================
;; Bulk reclassification filtering tests
;; =============================================================================

(defn should-reclassify?
  "Check if a document should be reclassified (from bulk_reclassify)"
  [doc {:keys [classification]}]
  (and
   (not (:classification_override doc))
   (or (nil? classification)
       (= classification (:classification doc)))))

(deftest should-reclassify-test
  (testing "Includes document without override and no filter"
    (let [doc {:PK "test.md" :classification "meeting"}]
      (is (true? (should-reclassify? doc {})))))

  (testing "Excludes document with override set"
    (let [doc {:PK "test.md" :classification "meeting" :classification_override true}]
      (is (false? (should-reclassify? doc {})))))

  (testing "Includes document matching classification filter"
    (let [doc {:PK "test.md" :classification "meeting"}]
      (is (true? (should-reclassify? doc {:classification "meeting"})))))

  (testing "Excludes document not matching classification filter"
    (let [doc {:PK "test.md" :classification "idea"}]
      (is (false? (should-reclassify? doc {:classification "meeting"})))))

  (testing "Excludes overridden document even when matching filter"
    (let [doc {:PK "test.md" :classification "meeting" :classification_override true}]
      (is (false? (should-reclassify? doc {:classification "meeting"})))))

  (testing "Bulk filtering across multiple documents"
    (let [docs [{:PK "a.md" :classification "meeting"}
                {:PK "b.md" :classification "idea"}
                {:PK "c.md" :classification "meeting" :classification_override true}
                {:PK "d.md" :classification "reference"}
                {:PK "e.md" :classification "meeting"}]
          eligible (filter #(should-reclassify? % {:classification "meeting"}) docs)]
      (is (= 2 (count eligible)))
      (is (= #{"a.md" "e.md"} (set (map :PK eligible)))))))

;; =============================================================================
;; Update classification API validation tests
;; =============================================================================

(deftest update-classification-validation-test
  (testing "Valid classifications are accepted"
    (doseq [cls ["meeting" "idea" "reference" "journal" "project"]]
      (is (contains? valid-classifications cls)
          (str cls " should be valid"))))

  (testing "Mixed-case classifications are accepted after normalization"
    (doseq [cls ["Meeting" "IDEA" "Reference"]]
      (is (contains? valid-classifications (-> cls str/trim str/lower-case))
          (str (pr-str cls) " should be accepted after lowercasing"))))

  (testing "Invalid classifications are rejected"
    (doseq [cls ["note" "task" ""]]
      (is (not (contains? valid-classifications (-> cls str/trim str/lower-case)))
          (str (pr-str cls) " should be rejected")))))

;; =============================================================================
;; Markdown fence stripping tests (covers both classify and entity extraction)
;; =============================================================================

(deftest strip-markdown-fences-test
  (testing "Strips ```json fences"
    (is (= "{\"key\": \"value\"}"
           (strip-markdown-fences "```json\n{\"key\": \"value\"}\n```"))))

  (testing "Strips plain ``` fences"
    (is (= "{\"key\": \"value\"}"
           (strip-markdown-fences "```\n{\"key\": \"value\"}\n```"))))

  (testing "Strips fences with other language identifiers"
    (is (= "{\"key\": \"value\"}"
           (strip-markdown-fences "```text\n{\"key\": \"value\"}\n```"))))

  (testing "Passes through plain JSON unchanged"
    (is (= "{\"key\": \"value\"}"
           (strip-markdown-fences "{\"key\": \"value\"}"))))

  (testing "Trims surrounding whitespace"
    (is (= "{\"key\": \"value\"}"
           (strip-markdown-fences "  {\"key\": \"value\"}  "))))

  (testing "Entity extraction JSON parses after fence stripping"
    (let [fenced "```json\n{\"people\": [\"John\"], \"organizations\": [\"Acme\"], \"concepts\": [\"AI\"], \"locations\": [\"NYC\"]}\n```"
          cleaned (strip-markdown-fences fenced)
          parsed (json/parse-string cleaned true)]
      (is (= ["John"] (:people parsed)))
      (is (= ["Acme"] (:organizations parsed)))
      (is (= ["AI"] (:concepts parsed)))
      (is (= ["NYC"] (:locations parsed))))))

;; =============================================================================
;; Frontmatter classification signal detection tests
;; (Duplicated from classify_document/handler.clj for testability)
;; =============================================================================

(def ^:private tag-signals
  {"journal"   #{"daily-notes" "daily-note" "daily" "journal" "diary"}
   "meeting"   #{"meeting" "meetings" "meeting-notes" "meeting-note"
                 "standup" "1on1" "1-on-1" "retro" "retrospective"}
   "project"   #{"project" "project-plan" "roadmap" "sprint"}
   "idea"      #{"idea" "ideas" "brainstorm" "concept" "proposal"}
   "reference" #{"reference" "howto" "how-to" "guide" "cheatsheet"
                 "cheat-sheet" "documentation" "docs"}})

(def ^:private type-signals
  {"journal"   #{"daily" "journal" "daily-note" "daily-notes"}
   "meeting"   #{"meeting" "meetings"}
   "project"   #{"project"}
   "idea"      #{"idea"}
   "reference" #{"reference" "howto" "guide"}})

(def ^:private path-signals
  {"journal"   #{"daily notes" "daily" "journal"}
   "meeting"   #{"meetings" "meeting notes"}
   "project"   #{"projects"}})

(defn detect-classification-from-frontmatter
  "Detect classification from frontmatter signals and file path.
   Returns {:classification string :confidence number :signal string} if a
   strong signal is found, nil otherwise."
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

        ;; Check file path segments
        (some (fn [[classification path-parts]]
                (when-let [match (first (filter #(str/includes? path-lower (str % "/")) path-parts))]
                  {:classification classification
                   :confidence 0.9
                   :signal (str "path:" match "/")}))
              path-signals))))

;; --- Tag signal tests ---

(deftest frontmatter-tag-signals-test
  (testing "daily-notes tag classifies as journal"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["daily-notes"]} "notes/2024-01-15.md")]
      (is (= "journal" (:classification result)))
      (is (= 1.0 (:confidence result)))
      (is (= "tag:daily-notes" (:signal result)))))

  (testing "daily tag classifies as journal"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["daily"]} "notes/today.md")]
      (is (= "journal" (:classification result)))))

  (testing "journal tag classifies as journal"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["journal"]} "entries/reflection.md")]
      (is (= "journal" (:classification result)))))

  (testing "diary tag classifies as journal"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["diary"]} "personal/entry.md")]
      (is (= "journal" (:classification result)))))

  (testing "meeting tag classifies as meeting"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["meeting"]} "work/standup.md")]
      (is (= "meeting" (:classification result)))
      (is (= "tag:meeting" (:signal result)))))

  (testing "standup tag classifies as meeting"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["standup"]} "work/daily-standup.md")]
      (is (= "meeting" (:classification result)))))

  (testing "meeting-notes tag classifies as meeting"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["meeting-notes"]} "work/notes.md")]
      (is (= "meeting" (:classification result)))))

  (testing "retro tag classifies as meeting"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["retro"]} "work/sprint-retro.md")]
      (is (= "meeting" (:classification result)))))

  (testing "project tag classifies as project"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["project"]} "work/app-redesign.md")]
      (is (= "project" (:classification result)))))

  (testing "roadmap tag classifies as project"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["roadmap"]} "plans/q1.md")]
      (is (= "project" (:classification result)))))

  (testing "idea tag classifies as idea"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["idea"]} "thoughts/new-feature.md")]
      (is (= "idea" (:classification result)))))

  (testing "brainstorm tag classifies as idea"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["brainstorm"]} "thoughts/session.md")]
      (is (= "idea" (:classification result)))))

  (testing "reference tag classifies as reference"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["reference"]} "docs/api.md")]
      (is (= "reference" (:classification result)))))

  (testing "howto tag classifies as reference"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["howto"]} "guides/setup.md")]
      (is (= "reference" (:classification result)))))

  (testing "tags are case-insensitive"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["Daily-Notes"]} "notes/today.md")]
      (is (= "journal" (:classification result)))))

  (testing "mixed tags - first matching signal wins"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["unrelated" "daily-notes" "work"]} "notes/today.md")]
      (is (= "journal" (:classification result))))))

;; --- Type field signal tests ---

(deftest frontmatter-type-signals-test
  (testing "type: daily classifies as journal"
    (let [result (detect-classification-from-frontmatter
                   {:type "daily"} "notes/2024-01-15.md")]
      (is (= "journal" (:classification result)))
      (is (= 1.0 (:confidence result)))
      (is (= "type:daily" (:signal result)))))

  (testing "type: journal classifies as journal"
    (let [result (detect-classification-from-frontmatter
                   {:type "journal"} "entries/today.md")]
      (is (= "journal" (:classification result)))))

  (testing "type: meeting classifies as meeting"
    (let [result (detect-classification-from-frontmatter
                   {:type "meeting"} "work/sync.md")]
      (is (= "meeting" (:classification result)))))

  (testing "type: project classifies as project"
    (let [result (detect-classification-from-frontmatter
                   {:type "project"} "work/redesign.md")]
      (is (= "project" (:classification result)))))

  (testing "type: idea classifies as idea"
    (let [result (detect-classification-from-frontmatter
                   {:type "idea"} "thoughts/concept.md")]
      (is (= "idea" (:classification result)))))

  (testing "type: reference classifies as reference"
    (let [result (detect-classification-from-frontmatter
                   {:type "reference"} "docs/cheatsheet.md")]
      (is (= "reference" (:classification result)))))

  (testing "type field is case-insensitive"
    (let [result (detect-classification-from-frontmatter
                   {:type "Meeting"} "work/sync.md")]
      (is (= "meeting" (:classification result))))))

;; --- CSS class signal tests ---

(deftest frontmatter-cssclass-signals-test
  (testing "cssclass: daily classifies as journal"
    (let [result (detect-classification-from-frontmatter
                   {:cssclass "daily"} "notes/today.md")]
      (is (= "journal" (:classification result)))
      (is (str/starts-with? (:signal result) "cssclass:"))))

  (testing "cssclasses array with journal classifies as journal"
    (let [result (detect-classification-from-frontmatter
                   {:cssclasses ["wide" "journal"]} "notes/today.md")]
      (is (= "journal" (:classification result)))))

  (testing "cssclass with meeting classifies as meeting"
    (let [result (detect-classification-from-frontmatter
                   {:cssclass "meeting"} "work/sync.md")]
      (is (= "meeting" (:classification result))))))

;; --- Path signal tests ---

(deftest frontmatter-path-signals-test
  (testing "daily notes/ path classifies as journal"
    (let [result (detect-classification-from-frontmatter
                   {} "daily notes/2024-01-15.md")]
      (is (= "journal" (:classification result)))
      (is (= 0.9 (:confidence result)))
      (is (str/starts-with? (:signal result) "path:"))))

  (testing "daily/ path classifies as journal"
    (let [result (detect-classification-from-frontmatter
                   {} "daily/2024-01-15.md")]
      (is (= "journal" (:classification result)))))

  (testing "journal/ path classifies as journal"
    (let [result (detect-classification-from-frontmatter
                   {} "journal/reflection.md")]
      (is (= "journal" (:classification result)))))

  (testing "meetings/ path classifies as meeting"
    (let [result (detect-classification-from-frontmatter
                   {} "work/meetings/standup.md")]
      (is (= "meeting" (:classification result)))))

  (testing "projects/ path classifies as project"
    (let [result (detect-classification-from-frontmatter
                   {} "projects/app-redesign.md")]
      (is (= "project" (:classification result)))))

  (testing "path matching is case-insensitive"
    (let [result (detect-classification-from-frontmatter
                   {} "Daily Notes/2024-01-15.md")]
      (is (= "journal" (:classification result))))))

;; --- No signal / fallback tests ---

(deftest frontmatter-no-signal-test
  (testing "returns nil when no signals match"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["work" "personal"]} "notes/random.md")]
      (is (nil? result))))

  (testing "returns nil for empty metadata"
    (let [result (detect-classification-from-frontmatter {} "notes/random.md")]
      (is (nil? result))))

  (testing "returns nil for nil tags"
    (let [result (detect-classification-from-frontmatter {:tags nil} "notes/random.md")]
      (is (nil? result))))

  (testing "tags take priority over type field"
    (let [result (detect-classification-from-frontmatter
                   {:tags ["meeting"] :type "journal"} "notes/sync.md")]
      (is (= "meeting" (:classification result)))
      (is (str/starts-with? (:signal result) "tag:"))))

  (testing "type field takes priority over path"
    (let [result (detect-classification-from-frontmatter
                   {:type "idea"} "meetings/brainstorm.md")]
      (is (= "idea" (:classification result)))
      (is (str/starts-with? (:signal result) "type:")))))
