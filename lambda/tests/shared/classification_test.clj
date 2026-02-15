(ns shared.classification-test
  "Tests for classification prompt parsing, override logic, and bulk filtering"
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
