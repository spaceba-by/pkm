(ns shared.deletion-test
  "Tests for cascade document deletion logic"
  (:require [clojure.test :refer [deftest is testing]]
            [shared.deletion :as deletion]
            [aws.dynamodb :as ddb]))

(deftest cascade-delete-with-tags-and-entities-test
  (testing "Deletes METADATA, tag index, and entity index records"
    (let [deleted-keys (atom [])]
      (with-redefs [ddb/get-item (fn [_table key]
                                   (when (= key {:PK "notes/meeting.md" :SK "METADATA"})
                                     {:PK "notes/meeting.md"
                                      :SK "METADATA"
                                      :tags ["tag-a" "tag-b"]
                                      :entities {:people ["John" "Jane"]
                                                 :concepts ["AI"]}}))
                    ddb/delete-item (fn [_table key]
                                     (swap! deleted-keys conj key)
                                     nil)]
        (let [result (deletion/cascade-delete-document "test-table" "notes/meeting.md")]
          ;; Should delete 2 tags + 3 entities + 1 METADATA = 6 deletes
          (is (= 6 (count @deleted-keys)))

          ;; Check tag index deletes
          (is (some #(= {:PK "tag#tag-a" :SK "doc#notes/meeting.md"} %) @deleted-keys))
          (is (some #(= {:PK "tag#tag-b" :SK "doc#notes/meeting.md"} %) @deleted-keys))

          ;; Check entity index deletes
          (is (some #(= {:PK "entity#people#john" :SK "doc#notes/meeting.md"} %) @deleted-keys))
          (is (some #(= {:PK "entity#people#jane" :SK "doc#notes/meeting.md"} %) @deleted-keys))
          (is (some #(= {:PK "entity#concepts#ai" :SK "doc#notes/meeting.md"} %) @deleted-keys))

          ;; Check METADATA delete
          (is (some #(= {:PK "notes/meeting.md" :SK "METADATA"} %) @deleted-keys))

          ;; Check result summary
          (is (= "notes/meeting.md" (:document result)))
          (is (= 2 (:deleted-tags result)))
          (is (= 3 (:deleted-entities result)))
          (is (nil? (:already-deleted result))))))))

(deftest cascade-delete-idempotent-test
  (testing "Returns gracefully when METADATA is already deleted"
    (let [delete-called (atom false)]
      (with-redefs [ddb/get-item (fn [_table _key] nil)
                    ddb/delete-item (fn [_table _key]
                                     (reset! delete-called true))]
        (let [result (deletion/cascade-delete-document "test-table" "notes/gone.md")]
          (is (false? @delete-called))
          (is (= 0 (:deleted-tags result)))
          (is (= 0 (:deleted-entities result)))
          (is (true? (:already-deleted result))))))))

(deftest cascade-delete-no-tags-or-entities-test
  (testing "Only deletes METADATA when tags and entities are nil"
    (let [deleted-keys (atom [])]
      (with-redefs [ddb/get-item (fn [_table _key]
                                   {:PK "notes/bare.md"
                                    :SK "METADATA"
                                    :title "Bare document"})
                    ddb/delete-item (fn [_table key]
                                     (swap! deleted-keys conj key)
                                     nil)]
        (let [result (deletion/cascade-delete-document "test-table" "notes/bare.md")]
          (is (= 1 (count @deleted-keys)))
          (is (= {:PK "notes/bare.md" :SK "METADATA"} (first @deleted-keys)))
          (is (= 0 (:deleted-tags result)))
          (is (= 0 (:deleted-entities result))))))))

(deftest cascade-delete-empty-tags-and-entities-test
  (testing "Only deletes METADATA when tags and entities are empty"
    (let [deleted-keys (atom [])]
      (with-redefs [ddb/get-item (fn [_table _key]
                                   {:PK "notes/empty.md"
                                    :SK "METADATA"
                                    :tags []
                                    :entities {}})
                    ddb/delete-item (fn [_table key]
                                     (swap! deleted-keys conj key)
                                     nil)]
        (let [result (deletion/cascade-delete-document "test-table" "notes/empty.md")]
          (is (= 1 (count @deleted-keys)))
          (is (= {:PK "notes/empty.md" :SK "METADATA"} (first @deleted-keys)))
          (is (= 0 (:deleted-tags result)))
          (is (= 0 (:deleted-entities result))))))))

(deftest cascade-delete-entity-key-lowercasing-test
  (testing "Entity names are lowercased in the PK for index lookup"
    (let [deleted-keys (atom [])]
      (with-redefs [ddb/get-item (fn [_table _key]
                                   {:PK "notes/case.md"
                                    :SK "METADATA"
                                    :tags []
                                    :entities {:organizations ["Acme Corp"]}})
                    ddb/delete-item (fn [_table key]
                                     (swap! deleted-keys conj key)
                                     nil)]
        (deletion/cascade-delete-document "test-table" "notes/case.md")
        (is (some #(= {:PK "entity#organizations#acme corp" :SK "doc#notes/case.md"} %) @deleted-keys))))))
