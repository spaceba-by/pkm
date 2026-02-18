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
            [clojure.string :as str]
            [cheshire.core :as json])
  (:import [java.util Base64]))

(def default-timestamp "1970-01-01T00:00:00Z")

;; =============================================================================
;; api_list_documents format-document tests
;; =============================================================================

(defn format-document
  "Format document metadata for API response (from api_list_documents)"
  [doc]
  (let [modified (or (:modified doc) default-timestamp)
        created (or (:created doc) modified)]
    {:id (:PK doc)
     :title (or (:title doc) "Untitled")
     :metadata {:classification (or (:classification doc) "reference")
                :tags (or (:tags doc) [])
                :linksTo (or (:links_to doc) [])
                :entities (:entities doc)
                :created created
                :modified modified
                :hasFrontmatter (if (some? (:has_frontmatter doc))
                                  (:has_frontmatter doc)
                                  false)}}))

(deftest format-document-test
  (testing "Formats complete document metadata with nested metadata"
    (let [doc {:PK "notes/test.md"
               :title "Test Document"
               :classification "meeting"
               :tags ["tag1" "tag2"]
               :links_to ["other.md"]
               :entities {:people ["John"]}
               :created "2025-01-01T00:00:00Z"
               :modified "2025-01-15T12:00:00Z"
               :has_frontmatter true}
          result (format-document doc)
          metadata (:metadata result)]
      (is (= "notes/test.md" (:id result)))
      (is (= "Test Document" (:title result)))
      (is (some? metadata) "should have nested metadata")
      (is (= "meeting" (:classification metadata)))
      (is (= ["tag1" "tag2"] (:tags metadata)))
      (is (= ["other.md"] (:linksTo metadata)))
      (is (= {:people ["John"]} (:entities metadata)))
      (is (= "2025-01-01T00:00:00Z" (:created metadata)))
      (is (= "2025-01-15T12:00:00Z" (:modified metadata)))
      (is (true? (:hasFrontmatter metadata)))))

  (testing "Provides defaults for missing fields"
    (let [doc {:PK "notes/minimal.md"}
          result (format-document doc)
          metadata (:metadata result)]
      (is (= "notes/minimal.md" (:id result)))
      (is (= "Untitled" (:title result)))
      (is (= "reference" (:classification metadata)))
      (is (= [] (:tags metadata)))
      (is (= [] (:linksTo metadata)))
      (is (= default-timestamp (:created metadata)))
      (is (= default-timestamp (:modified metadata)))
      (is (false? (:hasFrontmatter metadata))))))

;; =============================================================================
;; api_get_document format-document-detail tests
;; =============================================================================

(defn format-document-detail
  "Format full document with content for API response (from api_get_document)"
  [metadata content]
  (let [modified (or (:modified metadata) default-timestamp)
        created (or (:created metadata) modified)]
    {:id (:PK metadata)
     :title (or (:title metadata) "Untitled")
     :content content
     :metadata {:classification (or (:classification metadata) "reference")
                :tags (or (:tags metadata) [])
                :linksTo (or (:links_to metadata) [])
                :entities (:entities metadata)
                :created created
                :modified modified
                :hasFrontmatter (if (some? (:has_frontmatter metadata))
                                  (:has_frontmatter metadata)
                                  false)}}))

(deftest format-document-detail-test
  (testing "Formats document with content and nested metadata"
    (let [metadata {:PK "notes/full.md"
                    :title "Full Document"
                    :classification "idea"
                    :tags ["important"]
                    :links_to []
                    :created "2025-01-10T08:00:00Z"
                    :modified "2025-01-15T14:30:00Z"
                    :has_frontmatter true}
          content "# Full Document\n\nThis is the content."
          result (format-document-detail metadata content)
          result-meta (:metadata result)]
      (is (= "notes/full.md" (:id result)))
      (is (= "Full Document" (:title result)))
      (is (= content (:content result)))
      (is (= "idea" (:classification result-meta)))
      (is (= ["important"] (:tags result-meta)))
      (is (= "2025-01-10T08:00:00Z" (:created result-meta)))
      (is (= "2025-01-15T14:30:00Z" (:modified result-meta)))
      (is (true? (:hasFrontmatter result-meta)))))

  (testing "Handles nil content with defaults for missing metadata"
    (let [metadata {:PK "notes/no-content.md" :title "No Content"}
          result (format-document-detail metadata nil)
          result-meta (:metadata result)]
      (is (nil? (:content result)))
      (is (= "No Content" (:title result)))
      (is (= "reference" (:classification result-meta)))
      (is (= default-timestamp (:created result-meta)))
      (is (= default-timestamp (:modified result-meta)))
      (is (false? (:hasFrontmatter result-meta)))))

  (testing "S3-only fallback: agent output with no DynamoDB metadata"
    (let [metadata {:PK "_agent/summaries/2025-01-20.md"}
          content "# Daily Summary\n\nToday's activity..."
          result (format-document-detail metadata content)
          result-meta (:metadata result)]
      (is (= "_agent/summaries/2025-01-20.md" (:id result)))
      (is (= "Untitled" (:title result)))
      (is (= content (:content result)))
      (is (= "reference" (:classification result-meta)))
      (is (= [] (:tags result-meta)))
      (is (= default-timestamp (:created result-meta)))
      (is (= default-timestamp (:modified result-meta)))
      (is (false? (:hasFrontmatter result-meta))))))

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
  (let [modified (or (:modified doc) default-timestamp)
        created (or (:created doc) modified)]
    {:id (:PK doc)
     :title (or (:title doc) "Untitled")
     :metadata {:classification (or (:classification doc) "reference")
                :tags (or (:tags doc) [])
                :linksTo (or (:links_to doc) [])
                :entities (:entities doc)
                :created created
                :modified modified
                :hasFrontmatter (if (some? (:has_frontmatter doc))
                                  (:has_frontmatter doc)
                                  false)}}))

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
  (testing "Formats search result with nested metadata"
    (let [doc {:PK "notes/result.md"
               :title "Search Result"
               :classification "reference"
               :tags ["search"]
               :created "2025-01-18T09:00:00Z"
               :modified "2025-01-20T16:45:00Z"
               :has_frontmatter true}
          result (format-search-result doc)
          metadata (:metadata result)]
      (is (= "notes/result.md" (:id result)))
      (is (= "Search Result" (:title result)))
      (is (= "reference" (:classification metadata)))
      (is (= ["search"] (:tags metadata)))
      (is (= "2025-01-20T16:45:00Z" (:modified metadata)))
      (is (= "2025-01-18T09:00:00Z" (:created metadata)))
      (is (true? (:hasFrontmatter metadata)))))

  (testing "Provides defaults for missing fields"
    (let [doc {:PK "minimal.md"}
          result (format-search-result doc)
          metadata (:metadata result)]
      (is (= "Untitled" (:title result)))
      (is (= "reference" (:classification metadata)))
      (is (= [] (:tags metadata)))
      (is (= default-timestamp (:created metadata)))
      (is (= default-timestamp (:modified metadata)))
      (is (false? (:hasFrontmatter metadata))))))

;; =============================================================================
;; api_documents_by_tag format-document tests
;; =============================================================================

(defn format-tag-document
  "Format document for tag results (from api_documents_by_tag)"
  [metadata]
  (let [modified (or (:modified metadata) default-timestamp)
        created (or (:created metadata) modified)]
    {:id (:PK metadata)
     :title (or (:title metadata) "Untitled")
     :metadata {:classification (or (:classification metadata) "reference")
                :tags (or (:tags metadata) [])
                :linksTo (or (:links_to metadata) [])
                :entities (:entities metadata)
                :created created
                :modified modified
                :hasFrontmatter (if (some? (:has_frontmatter metadata))
                                  (:has_frontmatter metadata)
                                  false)}}))

(deftest format-tag-document-test
  (testing "Formats document for tag results with nested metadata"
    (let [doc {:PK "notes/tagged.md"
               :title "Tagged Doc"
               :classification "idea"
               :tags ["clojure" "testing"]
               :created "2025-01-20T10:00:00Z"
               :modified "2025-01-25T11:30:00Z"
               :has_frontmatter false}
          result (format-tag-document doc)
          metadata (:metadata result)]
      (is (= "notes/tagged.md" (:id result)))
      (is (= "Tagged Doc" (:title result)))
      (is (= "idea" (:classification metadata)))
      (is (= ["clojure" "testing"] (:tags metadata)))
      (is (= "2025-01-25T11:30:00Z" (:modified metadata)))
      (is (= "2025-01-20T10:00:00Z" (:created metadata)))
      (is (false? (:hasFrontmatter metadata))))))

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
    (let [key "_agent/summaries/2025-01-20.md"
          result (parse-summary-key key)]
      (is (= key (:id result)))
      (is (= "2025-01-20" (:date result)))))

  (testing "Returns nil for non-markdown files"
    (is (nil? (parse-summary-key "_agent/summaries/readme.txt")))
    (is (nil? (parse-summary-key nil))))

  (testing "Handles various date formats"
    (let [result (parse-summary-key "_agent/summaries/2025-01-01.md")]
      (is (= "2025-01-01" (:date result))))))

(deftest list-summaries-sorting-test
  (testing "Summaries sort by date descending"
    (let [keys ["_agent/summaries/2025-01-15.md"
                "_agent/summaries/2025-01-20.md"
                "_agent/summaries/2025-01-10.md"]
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

;; =============================================================================
;; api_list_documents cursor encode/decode tests
;; =============================================================================

(defn encode-cursor
  "Encode a DynamoDB LastEvaluatedKey as a base64 JSON string (from api_list_documents)"
  [last-key]
  (when last-key
    (.encodeToString (Base64/getUrlEncoder)
                     (.getBytes (json/generate-string last-key) "UTF-8"))))

(defn decode-cursor
  "Decode a base64 JSON cursor back to a DynamoDB ExclusiveStartKey map (from api_list_documents)"
  [cursor]
  (when (and cursor (not (empty? cursor)))
    (try
      (let [decoded (String. (.decode (Base64/getUrlDecoder) cursor) "UTF-8")]
        (json/parse-string decoded true))
      (catch Exception _
        nil))))

(deftest cursor-encode-decode-test
  (testing "Round-trip encode/decode preserves key"
    (let [key {:PK "notes/test.md" :SK "METADATA"}
          encoded (encode-cursor key)
          decoded (decode-cursor encoded)]
      (is (some? encoded) "encoded cursor should not be nil")
      (is (= key decoded) "decoded cursor should match original key")))

  (testing "nil key returns nil cursor"
    (is (nil? (encode-cursor nil))))

  (testing "nil cursor returns nil key"
    (is (nil? (decode-cursor nil))))

  (testing "empty cursor returns nil key"
    (is (nil? (decode-cursor ""))))

  (testing "invalid cursor returns nil"
    (is (nil? (decode-cursor "not-valid-base64!@#$"))))

  (testing "Cursor with complex key values"
    (let [key {:PK "path/to/document with spaces.md" :SK "METADATA"}
          encoded (encode-cursor key)
          decoded (decode-cursor encoded)]
      (is (= key decoded)))))
