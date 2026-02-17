(ns shared.deletion
  "Shared cascade deletion logic for document cleanup.
   Used by delete_document Lambda and bulk_reclassify stale cleanup."
  (:require [aws.dynamodb :as ddb]
            [clojure.string :as str]))

(defn cascade-delete-document
  "Cascade-delete all DynamoDB records for a document.
   Deletes tag index entries, entity index entries, and the METADATA record.
   Idempotent: returns gracefully if METADATA is already gone."
  [table-name object-key]
  (let [metadata (ddb/get-item table-name {:PK object-key :SK "METADATA"})]
    (if (nil? metadata)
      (do
        (println "No METADATA record found for" object-key "- already deleted")
        {:document object-key :deleted-tags 0 :deleted-entities 0 :already-deleted true})

      (let [tags (or (:tags metadata) [])
            entities (or (:entities metadata) {})
            deleted-tags (atom 0)
            deleted-entities (atom 0)]

        ;; Delete tag index entries
        (doseq [tag tags]
          (try
            (ddb/delete-item table-name {:PK (str "tag#" tag) :SK (str "doc#" object-key)})
            (swap! deleted-tags inc)
            (catch Exception e
              (println "Error deleting tag index for" tag ":" (ex-message e)))))

        ;; Delete entity index entries
        (doseq [[entity-type entity-list] entities
                entity-name entity-list]
          (try
            (let [entity-key (str "entity#" (name entity-type) "#" (str/lower-case entity-name))]
              (ddb/delete-item table-name {:PK entity-key :SK (str "doc#" object-key)})
              (swap! deleted-entities inc))
            (catch Exception e
              (println "Error deleting entity index for" entity-name ":" (ex-message e)))))

        ;; Delete the METADATA record last
        (ddb/delete-item table-name {:PK object-key :SK "METADATA"})

        (let [result {:document object-key
                      :deleted-tags @deleted-tags
                      :deleted-entities @deleted-entities}]
          (println "Cascade-deleted records for" object-key
                   "- tags:" @deleted-tags "entities:" @deleted-entities)
          result)))))
