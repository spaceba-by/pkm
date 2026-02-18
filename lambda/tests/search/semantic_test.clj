(ns search.semantic-test
  "Tests for semantic search query interface"
  (:require [clojure.test :refer [deftest is testing]]
            [search.vector-index :as vi]
            [search.semantic :as semantic]))

(defn- make-test-index
  "Create a test index with known embeddings"
  []
  (-> (vi/create-index)
      (vi/upsert-chunks
       [{:path "meeting.md" :chunk_id 0 :heading "Standup"
         :content "Daily standup notes with team updates"
         :embedding [0.9 0.1 0.0 0.0]}
        {:path "meeting.md" :chunk_id 1 :heading "Action Items"
         :content "Follow up on deployment pipeline"
         :embedding [0.7 0.3 0.1 0.0]}
        {:path "clojure.md" :chunk_id 0 :heading "Basics"
         :content "Introduction to Clojure programming language"
         :embedding [0.0 0.0 0.9 0.1]}
        {:path "clojure.md" :chunk_id 1 :heading "Concurrency"
         :content "Atoms, refs, and agents for concurrent programming"
         :embedding [0.0 0.1 0.8 0.2]}
        {:path "ideas.md" :chunk_id 0 :heading "Project Ideas"
         :content "Build a semantic search engine for notes"
         :embedding [0.3 0.2 0.5 0.3]}])))

(deftest search-semantic-test
  (testing "Returns results using mock embedding function"
    (let [index (make-test-index)
          ;; Mock embed-fn that returns a query vector similar to meetings
          embed-fn (fn [_texts] [[0.9 0.1 0.0 0.0]])
          results (semantic/search-semantic index embed-fn "standup meeting")]
      (is (pos? (count results)))
      (is (= "meeting.md" (:path (first results))))))

  (testing "Returns empty results for unrelated query"
    (let [index (make-test-index)
          ;; Vector orthogonal to all content
          embed-fn (fn [_texts] [[0.0 0.0 0.0 1.0]])
          results (semantic/search-semantic index embed-fn "something unrelated"
                                           :min-score 0.9)]
      (is (empty? results)))))

(deftest group-by-document-test
  (testing "Groups results by document, keeping best score"
    (let [results [{:path "a.md" :chunk_id 0 :heading "H1" :content "Content one" :score 0.9}
                   {:path "a.md" :chunk_id 1 :heading "H2" :content "Content two" :score 0.7}
                   {:path "b.md" :chunk_id 0 :heading "H3" :content "Content three" :score 0.8}]
          grouped (semantic/group-by-document results)]
      (is (= 2 (count grouped)))
      ;; Best score first
      (is (= "a.md" (:path (first grouped))))
      (is (= 0.9 (:score (first grouped))))
      (is (= 2 (:chunk_count (first grouped))))
      ;; Second document
      (is (= "b.md" (:path (second grouped))))
      (is (= 0.8 (:score (second grouped))))
      (is (= 1 (:chunk_count (second grouped))))))

  (testing "Includes snippet from best-scoring chunk"
    (let [results [{:path "a.md" :chunk_id 0 :heading "Low" :content "Low score chunk" :score 0.5}
                   {:path "a.md" :chunk_id 1 :heading "High" :content "High score chunk" :score 0.95}]
          grouped (semantic/group-by-document results)]
      (is (= "High" (:heading (first grouped))))
      (is (.contains (:snippet (first grouped)) "High score"))))

  (testing "Returns empty for empty input"
    (is (empty? (semantic/group-by-document [])))))
