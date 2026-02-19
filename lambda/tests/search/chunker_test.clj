(ns search.chunker-test
  "Tests for markdown document chunking"
  (:require [clojure.test :refer [deftest is testing]]
            [search.chunker :as chunker]))

(deftest chunk-document-basic-test
  (testing "Splits document at heading boundaries"
    (let [content "# Introduction\n\nFirst section content.\n\n## Methods\n\nSecond section content."
          chunks (chunker/chunk-document "doc.md" content)]
      (is (= 2 (count chunks)))
      (is (= "Introduction" (:heading (first chunks))))
      (is (= "First section content." (:content (first chunks))))
      (is (= "Methods" (:heading (second chunks))))
      (is (= "Second section content." (:content (second chunks))))))

  (testing "Sets path and sequential chunk_ids"
    (let [content "# A\n\nContent A\n\n# B\n\nContent B"
          chunks (chunker/chunk-document "notes/test.md" content)]
      (is (every? #(= "notes/test.md" (:path %)) chunks))
      (is (= [0 1] (mapv :chunk_id chunks))))))

(deftest chunk-document-frontmatter-test
  (testing "Strips YAML frontmatter before chunking"
    (let [content "---\ntitle: Test\ntags: [a, b]\n---\n\n# Heading\n\nBody text."
          chunks (chunker/chunk-document "doc.md" content)]
      (is (= 1 (count chunks)))
      (is (= "Heading" (:heading (first chunks))))
      (is (= "Body text." (:content (first chunks))))))

  (testing "Does not include frontmatter as content"
    (let [content "---\ntitle: Test\n---\n\n# Section\n\nContent here."
          chunks (chunker/chunk-document "doc.md" content)]
      (is (not (some #(.contains (:content %) "title: Test") chunks))))))

(deftest chunk-document-no-headings-test
  (testing "Document without headings produces single chunk"
    (let [content "Just some plain text\nwithout any headings."
          chunks (chunker/chunk-document "doc.md" content :title "My Note")]
      (is (= 1 (count chunks)))
      (is (= "My Note" (:heading (first chunks))))
      (is (.contains (:content (first chunks)) "plain text"))))

  (testing "Uses empty heading when no title and no headings"
    (let [content "Plain text without anything special."
          chunks (chunker/chunk-document "doc.md" content)]
      (is (= 1 (count chunks)))
      (is (= "" (:heading (first chunks)))))))

(deftest chunk-document-nested-headings-test
  (testing "Handles multiple heading levels"
    (let [content (str "# Top Level\n\nIntro\n\n"
                       "## Sub Section\n\nSub content\n\n"
                       "### Deep Section\n\nDeep content\n\n"
                       "## Another Sub\n\nMore content")
          chunks (chunker/chunk-document "doc.md" content)]
      (is (= 4 (count chunks)))
      (is (= "Top Level" (:heading (first chunks))))
      (is (= "Sub Section" (:heading (second chunks))))
      (is (= "Deep Section" (:heading (nth chunks 2))))
      (is (= "Another Sub" (:heading (nth chunks 3)))))))

(deftest chunk-document-empty-sections-test
  (testing "Filters out empty sections (heading with no content)"
    (let [content "# Empty\n\n# Has Content\n\nSome text here."
          chunks (chunker/chunk-document "doc.md" content)]
      (is (= 1 (count chunks)))
      (is (= "Has Content" (:heading (first chunks))))))

  (testing "Handles blank content between headings"
    (let [content "# A\n\n   \n\n# B\n\nReal content"
          chunks (chunker/chunk-document "doc.md" content)]
      (is (= 1 (count chunks)))
      (is (= "B" (:heading (first chunks)))))))

(deftest chunk-document-content-before-first-heading-test
  (testing "Content before first heading becomes chunk with title"
    (let [content "Some preamble text.\n\n# First Heading\n\nHeading content."
          chunks (chunker/chunk-document "doc.md" content :title "My Document")]
      (is (= 2 (count chunks)))
      (is (= "My Document" (:heading (first chunks))))
      (is (= "Some preamble text." (:content (first chunks))))
      (is (= "First Heading" (:heading (second chunks)))))))

(deftest chunk-document-obsidian-features-test
  (testing "Preserves wikilinks in chunk content"
    (let [content "# Notes\n\nSee [[Other Note]] for details."
          chunks (chunker/chunk-document "doc.md" content)]
      (is (.contains (:content (first chunks)) "[[Other Note]]"))))

  (testing "Preserves tags in chunk content"
    (let [content "# Ideas\n\nThis is about #clojure and #babashka."
          chunks (chunker/chunk-document "doc.md" content)]
      (is (.contains (:content (first chunks)) "#clojure"))))

  (testing "Handles checkboxes"
    (let [content "# Tasks\n\n- [ ] Todo item\n- [x] Done item"
          chunks (chunker/chunk-document "doc.md" content)]
      (is (.contains (:content (first chunks)) "- [ ] Todo item")))))
