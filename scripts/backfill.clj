#!/usr/bin/env bb
;; Backfill pre-existing documents that were never processed by the PKM system.
;;
;; Compares S3 .md files against DynamoDB METADATA records to find unprocessed
;; documents, then triggers extract_metadata, classify_document, and
;; extract_entities Lambdas for each missing document.
;;
;; Usage (from lambda/ directory):
;;   bb -cp shared ../scripts/backfill.clj --dry-run
;;   bb -cp shared ../scripts/backfill.clj --execute
;;   bb -cp shared ../scripts/backfill.clj --execute --prefix "notes/2021" --limit 50
;;   bb -cp shared ../scripts/backfill.clj --execute --delay 1000
;;
;; Environment variables:
;;   S3_BUCKET_NAME       - S3 bucket name (required)
;;   DYNAMODB_TABLE_NAME  - DynamoDB table name (required)
;;   PROJECT_NAME         - Project name prefix for Lambda functions (default: pkm-agent)

(ns backfill
  (:require [aws.s3 :as s3]
            [aws.dynamodb :as ddb]
            [aws.lambda :as lambda]
            [clojure.string :as str]))

;; --- Configuration ---

(defn get-env!
  "Get required environment variable or exit with error"
  [var-name]
  (or (System/getenv var-name)
      (do (println "ERROR: Environment variable" var-name "is required")
          (System/exit 1))))

(def project-name (or (System/getenv "PROJECT_NAME") "pkm-agent"))

(def lambda-functions
  {:extract-metadata  (str project-name "-extract-metadata")
   :classify-document (str project-name "-classify-document")
   :extract-entities  (str project-name "-extract-entities")})

;; --- S3 document discovery ---

(defn skip-path?
  "Returns true if the path should be excluded from processing"
  [key]
  (or (str/starts-with? key "_agent/")
      (str/starts-with? key ".obsidian/")
      (not (str/ends-with? key ".md"))))

(defn list-s3-documents
  "List all .md files in S3, excluding agent and obsidian paths.
   Handles pagination for >1000 objects."
  [bucket prefix]
  (let [all-keys (s3/list-all-objects bucket (or prefix ""))]
    (remove skip-path? all-keys)))

;; --- DynamoDB existing records ---

(defn get-existing-document-keys
  "Scan DynamoDB for all existing METADATA records, return set of PK values"
  [table-name]
  (let [items (ddb/scan-all table-name
                            :filter-expr "SK = :sk"
                            :expr-attr-values {":sk" "METADATA"})]
    (set (map :PK items))))

;; --- Processing ---

(defn make-event
  "Construct an EventBridge-compatible event for Lambda invocation"
  [bucket s3-key]
  {:detail {:bucket {:name bucket}
            :object {:key s3-key}}})

(defn trigger-processing!
  "Invoke all 3 processing Lambdas for a document with rate limiting"
  [bucket s3-key delay-ms]
  (let [event (make-event bucket s3-key)]
    (doseq [[func-key func-name] lambda-functions]
      (lambda/invoke-async func-name event)
      (Thread/sleep (long (/ delay-ms 3))))))

;; --- CLI ---

(defn parse-args
  "Parse command-line arguments"
  [args]
  (loop [args args
         opts {:dry-run true
               :prefix nil
               :limit nil
               :delay 600}]
    (if (empty? args)
      opts
      (case (first args)
        "--dry-run"  (recur (rest args) (assoc opts :dry-run true))
        "--execute"  (recur (rest args) (assoc opts :dry-run false))
        "--prefix"   (recur (drop 2 args) (assoc opts :prefix (second args)))
        "--limit"    (recur (drop 2 args) (assoc opts :limit (parse-long (second args))))
        "--delay"    (recur (drop 2 args) (assoc opts :delay (parse-long (second args))))
        "-h"         (do (println "Usage: bb -cp shared ../scripts/backfill.clj [options]")
                         (println "")
                         (println "Options:")
                         (println "  --dry-run        Show what would be processed (default)")
                         (println "  --execute        Actually trigger Lambda processing")
                         (println "  --prefix PREFIX  Only process files under this S3 prefix")
                         (println "  --limit N        Process at most N documents")
                         (println "  --delay MS       Delay between documents in ms (default: 600)")
                         (System/exit 0))
        "--help"     (do (println "Usage: bb -cp shared ../scripts/backfill.clj [options]")
                         (println "")
                         (println "Options:")
                         (println "  --dry-run        Show what would be processed (default)")
                         (println "  --execute        Actually trigger Lambda processing")
                         (println "  --prefix PREFIX  Only process files under this S3 prefix")
                         (println "  --limit N        Process at most N documents")
                         (println "  --delay MS       Delay between documents in ms (default: 600)")
                         (System/exit 0))
        (do (println "Unknown option:" (first args))
            (System/exit 1))))))

(defn run!
  "Main entrypoint"
  [opts]
  (let [bucket     (get-env! "S3_BUCKET_NAME")
        table-name (get-env! "DYNAMODB_TABLE_NAME")
        {:keys [dry-run prefix limit delay]} opts]

    (println "=== PKM Document Backfill ===")
    (println "Bucket:" bucket)
    (println "Table:" table-name)
    (println "Mode:" (if dry-run "DRY RUN" "EXECUTE"))
    (when prefix (println "Prefix filter:" prefix))
    (when limit (println "Limit:" limit))
    (println "Delay between documents:" delay "ms")
    (println "")

    ;; Step 1: List S3 documents
    (println "Listing S3 documents...")
    (let [s3-keys (list-s3-documents bucket prefix)]
      (println "Found" (count s3-keys) "markdown files in S3")

      ;; Step 2: Get existing DynamoDB records
      (println "Scanning DynamoDB for existing records...")
      (let [existing-keys (get-existing-document-keys table-name)]
        (println "Found" (count existing-keys) "existing METADATA records")

        ;; Step 3: Compute diff
        (let [missing (remove existing-keys s3-keys)
              missing (if limit (take limit missing) missing)
              missing (vec missing)]
          (println "")
          (println "Documents needing backfill:" (count missing))

          (when (pos? (count missing))
            ;; Show sample
            (println "")
            (println "Sample paths:")
            (doseq [path (take 10 missing)]
              (println "  " path))
            (when (> (count missing) 10)
              (println "  ... and" (- (count missing) 10) "more")))

          (if dry-run
            ;; Dry run - just report
            (do
              (println "")
              (println "Dry run complete. Use --execute to process these documents."))

            ;; Execute - trigger Lambdas
            (let [triggered (atom 0)
                  errors (atom 0)]
              (println "")
              (println "Triggering processing for" (count missing) "documents...")
              (println "Lambda functions:" (str/join ", " (vals lambda-functions)))
              (println "")

              (doseq [[idx s3-key] (map-indexed vector missing)]
                (try
                  (trigger-processing! bucket s3-key delay)
                  (swap! triggered inc)
                  (when (zero? (mod (inc idx) 25))
                    (println "Progress:" (inc idx) "/" (count missing)))
                  (catch Exception e
                    (println "ERROR processing" s3-key ":" (ex-message e))
                    (swap! errors inc))))

              (println "")
              (println "=== Results ===")
              (println "Triggered:" @triggered)
              (println "Errors:" @errors))))))))

;; --- Main ---

(when (= *file* (System/getProperty "babashka.file"))
  (run! (parse-args *command-line-args*)))
