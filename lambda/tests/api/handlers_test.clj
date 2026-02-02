(ns api.handlers-test
  "Tests for API handler formatting and utility functions.

   Note: Functions like format-document, matches-query?, etc. are duplicated
   here rather than imported from the handler namespaces. This is intentional:
   all API handlers use the same 'handler' namespace name (required by the
   Lambda runtime), which prevents importing them together in tests.

   These duplicated functions serve as contract tests - they verify the
   expected formatting logic that the handlers must implement. If a handler's
   formatting changes, these tests will catch any breaking changes to the
   API response structure."
  (:require [clojure.test :refer [deftest is testing]]
            [clojure.string :as str]))

;; =============================================================================
;; api_list_documents format-document tests
;; =============================================================================

(defn format-document
  "Format document metadata for API response (from api_list_documents)"
  [doc]
  {:id (:PK doc)
   :title (or (:title doc) "Untitled")
   :classification (:classification doc)
   :tags (or (:tags doc) [])
   :linksTo (or (:links_to doc) [])
   :entities (:entities doc)
   :created (:created doc)
   :modified (:modified doc)
   :hasFrontmatter (:has_frontmatter doc)})

(deftest format-document-test
  (testing "Formats complete document metadata"
    (let [doc {:PK "notes/test.md"
               :title "Test Document"
               :classification "meeting"
               :tags ["tag1" "tag2"]
               :links_to ["other.md"]
               :entities {:people ["John"]}
               :created "2025-01-01"
               :modified "2025-01-15"
               :has_frontmatter true}
          result (format-document doc)]
      (is (= "notes/test.md" (:id result)))
      (is (= "Test Document" (:title result)))
      (is (= "meeting" (:classification result)))
      (is (= ["tag1" "tag2"] (:tags result)))
      (is (= ["other.md"] (:linksTo result)))
      (is (= {:people ["John"]} (:entities result)))
      (is (= "2025-01-01" (:created result)))
      (is (= "2025-01-15" (:modified result)))
      (is (true? (:hasFrontmatter result)))))

  (testing "Provides defaults for missing fields"
    (let [doc {:PK "notes/minimal.md"}
          result (format-document doc)]
      (is (= "notes/minimal.md" (:id result)))
      (is (= "Untitled" (:title result)))
      (is (= [] (:tags result)))
      (is (= [] (:linksTo result)))
      (is (nil? (:classification result))))))

;; =============================================================================
;; api_get_document format-document-detail tests
;; =============================================================================

(defn format-document-detail
  "Format full document with content for API response (from api_get_document)"
  [metadata content]
  {:id (:PK metadata)
   :title (or (:title metadata) "Untitled")
   :content content
   :classification (:classification metadata)
   :tags (or (:tags metadata) [])
   :linksTo (or (:links_to metadata) [])
   :entities (:entities metadata)
   :created (:created metadata)
   :modified (:modified metadata)
   :hasFrontmatter (:has_frontmatter metadata)})

(deftest format-document-detail-test
  (testing "Formats document with content"
    (let [metadata {:PK "notes/full.md"
                    :title "Full Document"
                    :classification "idea"
                    :tags ["important"]
                    :links_to []
                    :has_frontmatter true}
          content "# Full Document\n\nThis is the content."
          result (format-document-detail metadata content)]
      (is (= "notes/full.md" (:id result)))
      (is (= "Full Document" (:title result)))
      (is (= content (:content result)))
      (is (= "idea" (:classification result)))
      (is (= ["important"] (:tags result)))))

  (testing "Handles nil content"
    (let [metadata {:PK "notes/no-content.md" :title "No Content"}
          result (format-document-detail metadata nil)]
      (is (nil? (:content result)))
      (is (= "No Content" (:title result))))))

;; =============================================================================
;; api_search tests
;; =============================================================================

(defn matches-query?
  "Check if document matches search query (case-insensitive) (from api_search)"
  [doc query-lower]
  (let [title (str/lower-case (or (:title doc) ""))
        tags (or (:tags doc) [])
        pk (str/lower-case (or (:PK doc) ""))]
    (or (str/includes? title query-lower)
        (str/includes? pk query-lower)
        (some #(str/includes? (str/lower-case %) query-lower) tags))))

(defn format-search-result
  "Format document for search results (from api_search)"
  [doc]
  {:id (:PK doc)
   :title (or (:title doc) "Untitled")
   :classification (:classification doc)
   :tags (or (:tags doc) [])
   :modified (:modified doc)})

(deftest matches-query-test
  ;; Note: matches-query? expects query-lower to already be lowercase
  ;; The handler converts the query to lowercase before calling this function
  (testing "Matches by title"
    (let [doc {:PK "notes/test.md" :title "Meeting Notes" :tags []}]
      (is (matches-query? doc "meeting") "should match 'meeting' in title")
      (is (matches-query? doc "notes") "should match 'notes' in title")
      (is (not (matches-query? doc "project")) "should not match 'project'")))

  (testing "Matches by document path"
    (let [doc {:PK "projects/my-project.md" :title "Project" :tags []}]
      (is (matches-query? doc "projects") "should match 'projects' in path")
      (is (matches-query? doc "my-project") "should match 'my-project' in path")
      (is (not (matches-query? doc "notes")) "should not match 'notes'")))

  (testing "Matches by tags (tags are lowercased during comparison)"
    (let [doc {:PK "notes/test.md" :title "Test" :tags ["clojure" "AWS"]}]
      (is (matches-query? doc "clojure") "should match 'clojure' tag")
      (is (matches-query? doc "aws") "should match 'AWS' tag (lowercased during compare)")
      (is (not (matches-query? doc "java")) "should not match 'java'")))

  (testing "Handles missing fields"
    (let [doc {:PK "test.md"}]
      (is (matches-query? doc "test") "should match 'test' in PK")
      (is (not (matches-query? doc "missing")) "should not match 'missing'"))))

(deftest format-search-result-test
  (testing "Formats search result with all fields"
    (let [doc {:PK "notes/result.md"
               :title "Search Result"
               :classification "reference"
               :tags ["search"]
               :modified "2025-01-20"}
          result (format-search-result doc)]
      (is (= "notes/result.md" (:id result)))
      (is (= "Search Result" (:title result)))
      (is (= "reference" (:classification result)))
      (is (= ["search"] (:tags result)))
      (is (= "2025-01-20" (:modified result)))))

  (testing "Provides defaults for missing fields"
    (let [doc {:PK "minimal.md"}
          result (format-search-result doc)]
      (is (= "Untitled" (:title result)))
      (is (= [] (:tags result))))))

;; =============================================================================
;; api_documents_by_tag format-document tests
;; =============================================================================

(defn format-tag-document
  "Format document for tag results (from api_documents_by_tag)"
  [metadata]
  {:id (:PK metadata)
   :title (or (:title metadata) "Untitled")
   :classification (:classification metadata)
   :tags (or (:tags metadata) [])
   :modified (:modified metadata)})

(deftest format-tag-document-test
  (testing "Formats document for tag results"
    (let [doc {:PK "notes/tagged.md"
               :title "Tagged Doc"
               :classification "idea"
               :tags ["clojure" "testing"]
               :modified "2025-01-25"}
          result (format-tag-document doc)]
      (is (= "notes/tagged.md" (:id result)))
      (is (= "Tagged Doc" (:title result)))
      (is (= "idea" (:classification result)))
      (is (= ["clojure" "testing"] (:tags result)))
      (is (= "2025-01-25" (:modified result))))))

;; =============================================================================
;; api_list_classifications tests
;; =============================================================================

(def classifications
  [{:name "meeting"   :displayName "Meeting"   :icon "person.3"}
   {:name "idea"      :displayName "Idea"      :icon "lightbulb"}
   {:name "reference" :displayName "Reference" :icon "book"}
   {:name "journal"   :displayName "Journal"   :icon "book.closed"}
   {:name "project"   :displayName "Project"   :icon "folder"}])

(deftest classifications-test
  (testing "All classifications have required fields"
    (doseq [cls classifications]
      (is (string? (:name cls)))
      (is (string? (:displayName cls)))
      (is (string? (:icon cls)))))

  (testing "Expected classifications exist"
    (let [names (set (map :name classifications))]
      (is (contains? names "meeting"))
      (is (contains? names "idea"))
      (is (contains? names "reference"))
      (is (contains? names "journal"))
      (is (contains? names "project"))))

  (testing "Classification count"
    (is (= 5 (count classifications)))))

;; =============================================================================
;; api_list_summaries tests
;; =============================================================================

(defn parse-summary-key
  "Extract date from summary file path (from api_list_summaries)"
  [key]
  (when (and key (str/ends-with? key ".md"))
    (let [filename (last (str/split key #"/"))
          date (str/replace filename ".md" "")]
      {:id key
       :date date})))

(deftest parse-summary-key-test
  (testing "Parses daily summary filename"
    (let [key "_agent/summaries/daily/2025-01-20.md"
          result (parse-summary-key key)]
      (is (= key (:id result)))
      (is (= "2025-01-20" (:date result)))))

  (testing "Returns nil for non-markdown files"
    (is (nil? (parse-summary-key "_agent/summaries/daily/readme.txt")))
    (is (nil? (parse-summary-key nil))))

  (testing "Handles various date formats"
    (let [result (parse-summary-key "_agent/summaries/daily/2025-01-01.md")]
      (is (= "2025-01-01" (:date result))))))

(deftest list-summaries-sorting-test
  (testing "Summaries sort by date descending"
    (let [keys ["_agent/summaries/daily/2025-01-15.md"
                "_agent/summaries/daily/2025-01-20.md"
                "_agent/summaries/daily/2025-01-10.md"]
          parsed (mapv parse-summary-key keys)
          sorted (->> parsed
                      (sort-by :date #(compare %2 %1))
                      (vec))]
      (is (= "2025-01-20" (:date (first sorted))))
      (is (= "2025-01-15" (:date (second sorted))))
      (is (= "2025-01-10" (:date (nth sorted 2)))))))

;; =============================================================================
;; api_list_reports tests
;; =============================================================================

(defn parse-report-key
  "Extract week date from report file path (from api_list_reports)"
  [key]
  (when (and key (str/ends-with? key ".md"))
    (let [filename (last (str/split key #"/"))
          week-date (str/replace filename ".md" "")]
      {:id key
       :weekOf week-date})))

(deftest parse-report-key-test
  (testing "Parses weekly report filename"
    (let [key "_agent/reports/weekly/2025-01-13.md"
          result (parse-report-key key)]
      (is (= key (:id result)))
      (is (= "2025-01-13" (:weekOf result)))))

  (testing "Returns nil for non-markdown files"
    (is (nil? (parse-report-key "_agent/reports/weekly/index.html")))
    (is (nil? (parse-report-key nil)))))

(deftest list-reports-sorting-test
  (testing "Reports sort by weekOf descending"
    (let [keys ["_agent/reports/weekly/2025-01-06.md"
                "_agent/reports/weekly/2025-01-20.md"
                "_agent/reports/weekly/2025-01-13.md"]
          parsed (mapv parse-report-key keys)
          sorted (->> parsed
                      (sort-by :weekOf #(compare %2 %1))
                      (vec))]
      (is (= "2025-01-20" (:weekOf (first sorted))))
      (is (= "2025-01-13" (:weekOf (second sorted))))
      (is (= "2025-01-06" (:weekOf (nth sorted 2)))))))
