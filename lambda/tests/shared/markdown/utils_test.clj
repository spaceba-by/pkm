(ns shared.markdown.utils-test
  "Tests for markdown parsing utilities"
  (:require [clojure.test :refer [deftest is testing]]
            [markdown.utils :as md]))

(deftest extract-frontmatter-test
  (testing "Extracts YAML frontmatter from markdown"
    (let [content "---\ntitle: Test Document\ntags: [test, example]\n---\n\n# Hello World\n\nThis is content."
          [frontmatter body] (md/extract-frontmatter content)]
      (is (= "Test Document" (:title frontmatter)))
      (is (= ["test" "example"] (:tags frontmatter)))
      (is (.contains body "# Hello World"))))

  (testing "Returns nil frontmatter when none exists"
    (let [content "# No Frontmatter\n\nJust content."
          [frontmatter body] (md/extract-frontmatter content)]
      (is (nil? frontmatter))
      (is (= content body))))

  (testing "Handles empty frontmatter"
    (let [content "---\n---\n\nContent only"
          [frontmatter body] (md/extract-frontmatter content)]
      (is (or (nil? frontmatter) (empty? frontmatter)))
      (is (.contains body "Content only")))))

(deftest extract-wikilinks-test
  (testing "Extracts simple wikilinks"
    (let [content "Check out [[My Note]] and [[Another Note]]."
          links (md/extract-wikilinks content)]
      (is (= 2 (count links)))
      (is (some #(= "My Note" %) links))
      (is (some #(= "Another Note" %) links))))

  (testing "Extracts wikilinks with display text"
    (let [content "See [[actual-file|Display Text]] for more."
          links (md/extract-wikilinks content)]
      (is (= 1 (count links)))
      (is (= "actual-file" (first links)))))

  (testing "Returns empty vector when no wikilinks"
    (let [content "No links here, just plain text."
          links (md/extract-wikilinks content)]
      (is (empty? links))))

  (testing "Deduplicates wikilinks"
    (let [content "[[Note]] and [[Note]] again"
          links (md/extract-wikilinks content)]
      (is (= 1 (count links))))))

(deftest extract-tags-test
  (testing "Extracts inline hashtags"
    (let [content "This is about #clojure and #babashka"
          tags (md/extract-tags content nil)]
      (is (some #(= "clojure" %) tags))
      (is (some #(= "babashka" %) tags))))

  (testing "Extracts tags from frontmatter"
    (let [frontmatter {:tags ["aws" "lambda"]}
          tags (md/extract-tags "" frontmatter)]
      (is (some #(= "aws" %) tags))
      (is (some #(= "lambda" %) tags))))

  (testing "Combines frontmatter and inline tags"
    (let [frontmatter {:tags ["fromfm"]}
          content "And #inline tag"
          tags (md/extract-tags content frontmatter)]
      (is (some #(= "fromfm" %) tags))
      (is (some #(= "inline" %) tags))))

  (testing "Handles tags as comma-separated string"
    (let [frontmatter {:tags "tag1, tag2, tag3"}
          tags (md/extract-tags "" frontmatter)]
      (is (>= (count tags) 3)))))

(deftest extract-title-test
  (testing "Extracts title from frontmatter"
    (let [frontmatter {:title "My Title"}
          title (md/extract-title "" frontmatter)]
      (is (= "My Title" title))))

  (testing "Extracts title from H1 heading when no frontmatter"
    (let [content "# Document Title\n\nContent here"
          title (md/extract-title content nil)]
      (is (= "Document Title" title))))

  (testing "Returns Untitled when no title found"
    (let [content "No heading, no frontmatter"
          title (md/extract-title content nil)]
      (is (= "Untitled" title))))

  (testing "Prefers frontmatter title over H1"
    (let [frontmatter {:title "FM Title"}
          content "# H1 Title\n\nContent"
          title (md/extract-title content frontmatter)]
      (is (= "FM Title" title)))))

(deftest sanitize-filename-test
  (testing "Replaces spaces with hyphens"
    (is (= "my-file-name" (md/sanitize-filename "my file name"))))

  (testing "Removes invalid characters"
    (is (= "validname" (md/sanitize-filename "valid@name!"))))

  (testing "Converts to lowercase"
    (is (= "lowercase" (md/sanitize-filename "LOWERCASE"))))

  (testing "Handles complex filenames"
    (is (= "john-doe" (md/sanitize-filename "John Doe")))))

(deftest parse-markdown-metadata-test
  (testing "Parses complete markdown document"
    (let [content "---\ntitle: Test\ntags: [one, two]\n---\n\n# Test\n\nCheck [[Link1]] and #hashtag"
          metadata (md/parse-markdown-metadata content)]
      (is (= "Test" (:title metadata)))
      (is (vector? (:tags metadata)))
      (is (some #(= "Link1" %) (:links_to metadata)))
      (is (:has_frontmatter metadata))))

  (testing "Handles document without frontmatter"
    (let [content "# Simple Doc\n\nJust content with [[link]]"
          metadata (md/parse-markdown-metadata content)]
      (is (= "Simple Doc" (:title metadata)))
      (is (not (:has_frontmatter metadata)))
      (is (some #(= "link" %) (:links_to metadata))))))

(deftest create-frontmatter-test
  (testing "Creates valid YAML frontmatter"
    (let [metadata {:title "Test" :tags ["a" "b"]}
          fm (md/create-frontmatter metadata)]
      (is (.startsWith fm "---\n"))
      (is (.contains fm "title:"))
      (is (.endsWith fm "---\n")))))

(deftest create-classification-index-test
  (testing "Creates index with multiple classifications"
    (let [classifications {"meeting" ["doc1.md" "doc2.md"]
                          "idea" ["doc3.md"]
                          "project" []}
          index (md/create-classification-index classifications)]
      (is (.contains index "# Document Classifications"))
      (is (.contains index "## Meeting"))
      (is (.contains index "[[doc1.md]]"))
      (is (.contains index "## Idea"))
      (is (not (.contains index "## Project")))))) ;; Empty should be excluded
