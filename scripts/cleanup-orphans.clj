#!/usr/bin/env bb
;; Find and clean up orphaned DynamoDB records — METADATA entries
;; whose corresponding S3 objects no longer exist.
;;
;; Usage (from lambda/ directory):
;;   bb -cp shared ../scripts/cleanup-orphans.clj --dry-run
;;   bb -cp shared ../scripts/cleanup-orphans.clj --execute
;;   bb -cp shared ../scripts/cleanup-orphans.clj --execute --limit 50
;;   bb -cp shared ../scripts/cleanup-orphans.clj --execute --delay 500
;;
;; Environment variables:
;;   S3_BUCKET_NAME       - S3 bucket name (required)
;;   DYNAMODB_TABLE_NAME  - DynamoDB table name (required)

(ns cleanup-orphans
  (:require [aws.s3 :as s3]
            [aws.dynamodb :as ddb]
            [shared.deletion :as deletion]
            [clojure.string :as str]))

;; --- Configuration ---

(defn get-env!
  "Get required environment variable or exit with error"
  [var-name]
  (or (System/getenv var-name)
      (do (println "ERROR: Environment variable" var-name "is required")
          (System/exit 1))))

;; --- CLI ---

(def ^:private usage-text
  "Usage: bb -cp shared ../scripts/cleanup-orphans.clj [options]

Options:
  --dry-run        Show orphaned records without deleting (default)
  --execute        Actually cascade-delete orphaned records
  --limit N        Process at most N orphans
  --delay MS       Delay between deletions in ms (default: 200)")

(defn- require-arg [flag args]
  (when-not (second args)
    (println (str "ERROR: " flag " requires a value"))
    (System/exit 1))
  (second args))

(defn- require-int-arg [flag args]
  (let [raw (require-arg flag args)
        parsed (parse-long raw)]
    (when-not parsed
      (println (str "ERROR: " flag " requires an integer, got: " raw))
      (System/exit 1))
    parsed))

(defn parse-args [args]
  (loop [args args
         opts {:dry-run true :limit nil :delay 200}]
    (if (empty? args)
      opts
      (case (first args)
        "--dry-run" (recur (rest args) (assoc opts :dry-run true))
        "--execute" (recur (rest args) (assoc opts :dry-run false))
        "--limit"   (recur (drop 2 args) (assoc opts :limit (require-int-arg "--limit" args)))
        "--delay"   (recur (drop 2 args) (assoc opts :delay (require-int-arg "--delay" args)))
        ("-h" "--help") (do (println usage-text) (System/exit 0))
        (do (println "Unknown option:" (first args))
            (println usage-text)
            (System/exit 1))))))

;; --- Core Logic ---

(defn skip-path?
  "Returns true if the DynamoDB key is not a real document path"
  [key]
  (or (str/starts-with? key "_agent/")
      (str/starts-with? key ".obsidian/")
      (str/starts-with? key "tag#")
      (str/starts-with? key "entity#")
      (str/starts-with? key "classification#")))

(defn run! [opts]
  (let [bucket     (get-env! "S3_BUCKET_NAME")
        table-name (get-env! "DYNAMODB_TABLE_NAME")
        {:keys [dry-run limit delay]} opts]

    (println "=== PKM Orphan Cleanup ===")
    (println "Bucket:" bucket)
    (println "Table:" table-name)
    (println "Mode:" (if dry-run "DRY RUN" "EXECUTE"))
    (when limit (println "Limit:" limit))
    (println "Delay between deletions:" delay "ms")
    (println "")

    ;; Step 1: Scan all METADATA records from DynamoDB
    (println "Scanning DynamoDB for all METADATA records...")
    (let [items (ddb/scan-all table-name
                              :filter-expr "SK = :sk"
                              :expr-attr-values {":sk" "METADATA"})
          doc-keys (->> items
                        (map :PK)
                        (remove skip-path?)
                        vec)]
      (println "Found" (count doc-keys) "document METADATA records")

      ;; Step 2: Check each against S3
      (println "Checking S3 for existence...")
      (let [orphans (atom [])
            checked (atom 0)]
        (doseq [doc-key doc-keys]
          (swap! checked inc)
          (when (zero? (mod @checked 100))
            (println "  Checked" @checked "/" (count doc-keys) "..."))
          (when-not (s3/object-exists? bucket doc-key)
            (swap! orphans conj doc-key)))

        (println "")
        (println "Orphaned records (in DynamoDB but not S3):" (count @orphans))

        (when (pos? (count @orphans))
          (println "")
          (println "Orphaned paths:")
          (doseq [path (take 20 @orphans)]
            (println "  " path))
          (when (> (count @orphans) 20)
            (println "  ... and" (- (count @orphans) 20) "more")))

        (let [to-delete (if limit (take limit @orphans) @orphans)]
          (if dry-run
            (do
              (println "")
              (println "Dry run complete. Use --execute to delete these" (count to-delete) "orphaned records."))

            ;; Execute - cascade-delete each orphan
            (let [deleted (atom 0)
                  errors (atom 0)]
              (println "")
              (println "Cascade-deleting" (count to-delete) "orphaned records...")
              (println "")

              (doseq [[idx doc-key] (map-indexed vector to-delete)]
                (try
                  (let [result (deletion/cascade-delete-document table-name doc-key)]
                    (swap! deleted inc)
                    (println (str "  [" (inc idx) "/" (count to-delete) "] "
                                  doc-key " - tags:" (:deleted-tags result)
                                  " entities:" (:deleted-entities result)))
                    (Thread/sleep (long delay)))
                  (catch Exception e
                    (println "  ERROR deleting" doc-key ":" (ex-message e))
                    (swap! errors inc))))

              (println "")
              (println "=== Results ===")
              (println "Deleted:" @deleted)
              (println "Errors:" @errors))))))))

;; --- Main ---

(when (= *file* (System/getProperty "babashka.file"))
  (run! (parse-args *command-line-args*)))
