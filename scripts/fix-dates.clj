#!/usr/bin/env bb
;; Fix document dates in DynamoDB by resolving from frontmatter and S3 metadata.
;;
;; Scans all METADATA records in DynamoDB, re-reads document content from S3,
;; and updates created/modified timestamps using the priority:
;;   1. Frontmatter dates (created, modified, date)
;;   2. S3 object LastModified
;;   3. Leave existing DynamoDB value unchanged
;;
;; Usage (from lambda/ directory):
;;   bb -cp shared ../scripts/fix-dates.clj --dry-run
;;   bb -cp shared ../scripts/fix-dates.clj --execute
;;   bb -cp shared ../scripts/fix-dates.clj --execute --prefix "notes/2021" --limit 50
;;
;; Environment variables:
;;   S3_BUCKET_NAME       - S3 bucket name (required)
;;   DYNAMODB_TABLE_NAME  - DynamoDB table name (required)

(ns fix-dates
  (:require [aws.s3 :as s3]
            [aws.dynamodb :as ddb]
            [markdown.utils :as md]
            [clojure.string :as str]))

;; --- Configuration ---

(defn get-env!
  "Get required environment variable or exit with error"
  [var-name]
  (or (System/getenv var-name)
      (do (println "ERROR: Environment variable" var-name "is required")
          (System/exit 1))))

;; --- Date resolution ---

(defn resolve-dates
  "Resolve correct dates for a document from frontmatter and S3 metadata.
   Returns a map with any of {:created <iso> :modified <iso>} for fields that
   should be updated, or nil if no changes are needed."
  [metadata s3-last-modified existing-record]
  (let [fm-created (md/normalize-date (or (:created metadata) (:date metadata)))
        fm-modified (md/normalize-date (:modified metadata))
        s3-date (md/format-s3-date s3-last-modified)
        ;; Determine best dates
        best-created (or fm-created s3-date)
        best-modified (or fm-modified s3-date)
        current-created (:created existing-record)
        current-modified (:modified existing-record)
        ;; Only update if we have better data
        update-created (and best-created (not= best-created current-created))
        update-modified (and best-modified (not= best-modified current-modified))]
    (when (or update-created update-modified)
      (cond-> {}
        update-created  (assoc :created best-created)
        update-modified (assoc :modified best-modified)))))

;; --- Processing ---

(defn fix-document-dates!
  "Fix dates for a single document. Returns :updated, :skipped, or :error."
  [bucket table-name s3-key existing-record]
  (try
    ;; Read document content from S3
    (let [content (s3/get-object bucket s3-key)
          metadata (md/parse-markdown-metadata content)
          s3-meta (s3/get-object-metadata bucket s3-key)
          date-updates (resolve-dates metadata (:last-modified s3-meta) existing-record)]
      (if date-updates
        (do
          (ddb/update-item-attrs table-name
                                 {:PK s3-key :SK "METADATA"}
                                 date-updates)
          :updated)
        :skipped))
    (catch Exception e
      (println "  ERROR:" s3-key "-" (ex-message e))
      :error)))

;; --- CLI ---

(def ^:private usage-text
  "Usage: bb -cp shared ../scripts/fix-dates.clj [options]

Options:
  --dry-run        Show what would be updated (default)
  --execute        Actually update DynamoDB records
  --prefix PREFIX  Only process files under this S3 prefix
  --limit N        Process at most N documents")

(defn- require-arg
  [flag args]
  (when-not (second args)
    (println (str "ERROR: " flag " requires a value"))
    (System/exit 1))
  (second args))

(defn- require-int-arg
  [flag args]
  (let [raw (require-arg flag args)
        parsed (parse-long raw)]
    (when-not parsed
      (println (str "ERROR: " flag " requires an integer, got: " raw))
      (System/exit 1))
    parsed))

(defn parse-args
  [args]
  (loop [args args
         opts {:dry-run true
               :prefix nil
               :limit nil}]
    (if (empty? args)
      opts
      (case (first args)
        "--dry-run"  (recur (rest args) (assoc opts :dry-run true))
        "--execute"  (recur (rest args) (assoc opts :dry-run false))
        "--prefix"   (recur (drop 2 args) (assoc opts :prefix (require-arg "--prefix" args)))
        "--limit"    (recur (drop 2 args) (assoc opts :limit (require-int-arg "--limit" args)))
        ("-h" "--help") (do (println usage-text) (System/exit 0))
        (do (println "Unknown option:" (first args))
            (println usage-text)
            (System/exit 1))))))

(defn run!
  [opts]
  (let [bucket     (get-env! "S3_BUCKET_NAME")
        table-name (get-env! "DYNAMODB_TABLE_NAME")
        {:keys [dry-run prefix limit]} opts]

    (println "=== PKM Fix Document Dates ===")
    (println "Bucket:" bucket)
    (println "Table:" table-name)
    (println "Mode:" (if dry-run "DRY RUN" "EXECUTE"))
    (when prefix (println "Prefix filter:" prefix))
    (when limit (println "Limit:" limit))
    (println "")

    ;; Scan all METADATA records
    (println "Scanning DynamoDB for METADATA records...")
    (let [all-records (ddb/scan-all table-name
                                    :filter-expr "SK = :sk"
                                    :expr-attr-values {":sk" "METADATA"})
          ;; Filter by prefix if specified
          records (cond->> all-records
                    prefix (filter #(str/starts-with? (or (:PK %) "") prefix))
                    ;; Skip agent-generated docs
                    true (remove #(str/starts-with? (or (:PK %) "") "_agent/"))
                    limit (take limit))
          records (vec records)]

      (println "Found" (count all-records) "total METADATA records")
      (println "Processing" (count records) "records"
               (when prefix (str "(prefix: " prefix ")"))
               (when limit (str "(limit: " limit ")")))
      (println "")

      (if dry-run
        ;; Dry run: show what would change
        (let [would-update (atom 0)
              would-skip (atom 0)
              errors (atom 0)]
          (doseq [[idx record] (map-indexed vector records)]
            (let [s3-key (:PK record)]
              (try
                (let [content (s3/get-object bucket s3-key)
                      metadata (md/parse-markdown-metadata content)
                      s3-meta (s3/get-object-metadata bucket s3-key)
                      date-updates (resolve-dates metadata (:last-modified s3-meta) record)]
                  (if date-updates
                    (do
                      (swap! would-update inc)
                      (println "  WOULD UPDATE:" s3-key)
                      (when (:created date-updates)
                        (println "    created:" (:created record) "→" (:created date-updates)))
                      (when (:modified date-updates)
                        (println "    modified:" (:modified record) "→" (:modified date-updates))))
                    (swap! would-skip inc)))
                (catch Exception e
                  (println "  ERROR reading" s3-key ":" (ex-message e))
                  (swap! errors inc)))
              (when (zero? (mod (inc idx) 100))
                (println "Progress:" (inc idx) "/" (count records)))))

          (println "")
          (println "=== Dry Run Results ===")
          (println "Would update:" @would-update)
          (println "Would skip (no change):" @would-skip)
          (println "Errors:" @errors)
          (println "")
          (println "Use --execute to apply these changes."))

        ;; Execute: actually update records
        (let [updated (atom 0)
              skipped (atom 0)
              errors (atom 0)]
          (doseq [[idx record] (map-indexed vector records)]
            (let [s3-key (:PK record)
                  result (fix-document-dates! bucket table-name s3-key record)]
              (case result
                :updated (do (swap! updated inc)
                             (println "  UPDATED:" s3-key))
                :skipped (swap! skipped inc)
                :error (swap! errors inc))
              (when (zero? (mod (inc idx) 100))
                (println "Progress:" (inc idx) "/" (count records)))))

          (println "")
          (println "=== Results ===")
          (println "Updated:" @updated)
          (println "Skipped (no change):" @skipped)
          (println "Errors:" @errors))))))

;; --- Main ---

(when (= *file* (System/getProperty "babashka.file"))
  (run! (parse-args *command-line-args*)))
