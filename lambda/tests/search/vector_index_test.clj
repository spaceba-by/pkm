(ns search.vector-index-test
  "Tests for vector similarity search index"
  (:require [clojure.test :refer [deftest is testing]]
            [search.vector-index :as vi]))

(deftest cosine-similarity-test
  (testing "Identical vectors have similarity 1.0"
    (is (== 1.0 (vi/cosine-similarity [1.0 0.0 0.0] [1.0 0.0 0.0]))))

  (testing "Orthogonal vectors have similarity 0.0"
    (is (== 0.0 (vi/cosine-similarity [1.0 0.0 0.0] [0.0 1.0 0.0]))))

  (testing "Opposite vectors have similarity -1.0"
    (is (== -1.0 (vi/cosine-similarity [1.0 0.0] [-1.0 0.0]))))

  (testing "Similar vectors have positive similarity"
    (let [sim (vi/cosine-similarity [1.0 1.0 0.0] [1.0 0.5 0.0])]
      (is (> sim 0.9))
      (is (<= sim 1.0))))

  (testing "Zero vector returns 0.0"
    (is (== 0.0 (vi/cosine-similarity [0.0 0.0] [1.0 1.0])))
    (is (== 0.0 (vi/cosine-similarity [1.0 1.0] [0.0 0.0])))))

(deftest create-index-test
  (testing "Creates index with schema version and empty chunks"
    (let [index (vi/create-index)]
      (is (= 1 (:schema_version index)))
      (is (empty? (:chunks index))))))

(deftest upsert-chunks-test
  (testing "Inserts new chunks"
    (let [index (vi/create-index)
          chunks [{:path "a.md" :chunk_id 0 :content "hello" :embedding [1.0 0.0]}
                  {:path "a.md" :chunk_id 1 :content "world" :embedding [0.0 1.0]}]
          updated (vi/upsert-chunks index chunks)]
      (is (= 2 (vi/chunk-count updated)))))

  (testing "Replaces existing chunks with same path+chunk_id"
    (let [index (vi/create-index)
          old [{:path "a.md" :chunk_id 0 :content "old" :embedding [1.0 0.0]}]
          new [{:path "a.md" :chunk_id 0 :content "new" :embedding [0.0 1.0]}]
          updated (-> index (vi/upsert-chunks old) (vi/upsert-chunks new))]
      (is (= 1 (vi/chunk-count updated)))
      (is (= "new" (:content (first (:chunks updated)))))))

  (testing "Preserves chunks from other documents"
    (let [index (vi/create-index)
          doc-a [{:path "a.md" :chunk_id 0 :content "a" :embedding [1.0 0.0]}]
          doc-b [{:path "b.md" :chunk_id 0 :content "b" :embedding [0.0 1.0]}]
          updated (-> index (vi/upsert-chunks doc-a) (vi/upsert-chunks doc-b))]
      (is (= 2 (vi/chunk-count updated))))))

(deftest remove-document-test
  (testing "Removes all chunks for a document"
    (let [index (vi/create-index)
          chunks [{:path "a.md" :chunk_id 0 :content "a0" :embedding [1.0 0.0]}
                  {:path "a.md" :chunk_id 1 :content "a1" :embedding [0.0 1.0]}
                  {:path "b.md" :chunk_id 0 :content "b0" :embedding [1.0 1.0]}]
          updated (-> index (vi/upsert-chunks chunks) (vi/remove-document "a.md"))]
      (is (= 1 (vi/chunk-count updated)))
      (is (= "b.md" (:path (first (:chunks updated)))))))

  (testing "No-op when document not in index"
    (let [index (-> (vi/create-index)
                    (vi/upsert-chunks [{:path "a.md" :chunk_id 0 :content "a" :embedding [1.0]}]))
          updated (vi/remove-document index "nonexistent.md")]
      (is (= 1 (vi/chunk-count updated))))))

(deftest search-test
  (testing "Returns results sorted by similarity"
    (let [index (vi/create-index)
          chunks [{:path "a.md" :chunk_id 0 :heading "A" :content "close"
                   :embedding [0.9 0.1 0.0]}
                  {:path "b.md" :chunk_id 0 :heading "B" :content "far"
                   :embedding [0.0 0.0 1.0]}
                  {:path "c.md" :chunk_id 0 :heading "C" :content "closest"
                   :embedding [1.0 0.0 0.0]}]
          index (vi/upsert-chunks index chunks)
          results (vi/search index [1.0 0.0 0.0] :top-k 3)]
      (is (= 3 (count results)))
      (is (= "c.md" (:path (first results))))
      (is (= "a.md" (:path (second results))))))

  (testing "Respects top-k limit"
    (let [index (-> (vi/create-index)
                    (vi/upsert-chunks [{:path "a.md" :chunk_id 0 :heading "A"
                                        :content "a" :embedding [1.0 0.0]}
                                       {:path "b.md" :chunk_id 0 :heading "B"
                                        :content "b" :embedding [0.5 0.5]}]))
          results (vi/search index [1.0 0.0] :top-k 1)]
      (is (= 1 (count results)))))

  (testing "Filters by min-score"
    (let [index (-> (vi/create-index)
                    (vi/upsert-chunks [{:path "a.md" :chunk_id 0 :heading "A"
                                        :content "a" :embedding [1.0 0.0]}
                                       {:path "b.md" :chunk_id 0 :heading "B"
                                        :content "b" :embedding [0.0 1.0]}]))
          results (vi/search index [1.0 0.0] :min-score 0.5)]
      (is (= 1 (count results)))
      (is (= "a.md" (:path (first results))))))

  (testing "Results do not include embedding vectors"
    (let [index (-> (vi/create-index)
                    (vi/upsert-chunks [{:path "a.md" :chunk_id 0 :heading "A"
                                        :content "a" :embedding [1.0 0.0]}]))
          results (vi/search index [1.0 0.0])]
      (is (nil? (:embedding (first results))))
      (is (number? (:score (first results)))))))

(deftest document-paths-test
  (testing "Returns unique document paths"
    (let [index (-> (vi/create-index)
                    (vi/upsert-chunks [{:path "a.md" :chunk_id 0 :content "a0" :embedding [1.0]}
                                       {:path "a.md" :chunk_id 1 :content "a1" :embedding [0.0]}
                                       {:path "b.md" :chunk_id 0 :content "b0" :embedding [1.0]}]))]
      (is (= #{"a.md" "b.md"} (vi/document-paths index))))))
