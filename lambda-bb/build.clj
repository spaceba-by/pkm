#!/usr/bin/env bb

(ns build
  "Build script for PKM Lambda functions using bblf"
  (:require [babashka.fs :as fs]
            [babashka.http-client :as http]
            [babashka.process :as p]
            [clojure.java.io :as io]
            [clojure.string :as str]))

(def bb-version "1.4.192")
(def bb-arch "linux-amd64-static")
(def target-dir "target")

(defn bb-url [version arch]
  (format "https://github.com/babashka/babashka/releases/download/v%s/babashka-%s-%s.tar.gz"
          version version arch))

(defn fetch-babashka [dest-dir]
  (println "Fetching babashka" bb-version "for" bb-arch "...")
  (let [url (bb-url bb-version bb-arch)
        response (http/get url {:as :stream})]
    (if (= 200 (:status response))
      (p/check (p/process {:in (:body response) :out :string}
                          (str "tar -C " dest-dir " -xz")))
      (throw (ex-info "Failed to fetch babashka" {:url url :status (:status response)})))))

(defn prepare-uberjar [function-dir dest-dir]
  (println "Creating uberjar for" function-dir "...")
  (fs/with-temp-dir [build-temp {}]
    (let [temp-path (str build-temp)]
      ;; Copy shared code
      (fs/copy-tree "shared" (str temp-path "/shared"))
      ;; Copy function code
      (fs/copy (str function-dir "/handler.clj") (str temp-path "/handler.clj"))
      ;; Create bb.edn with paths for uberjar
      (spit (str temp-path "/bb.edn")
            (pr-str {:paths ["." "shared"]
                     :deps {'clj-commons/clj-yaml {:mvn/version "1.0.27"}
                            'com.grzm/awyeah-api {:git/url "https://github.com/grzm/awyeah-api"
                                                  :git/sha "e5513349a2fd8a980a62bbe0d45a0d55bfcea141"}
                            'com.cognitect.aws/endpoints {:mvn/version "1.1.12.772"}
                            'com.cognitect.aws/s3 {:mvn/version "848.2.1413.0"}
                            'com.cognitect.aws/dynamodb {:mvn/version "848.2.1413.0"}
                            'com.cognitect.aws/lambda {:mvn/version "848.2.1413.0"}
                            'com.cognitect.aws/bedrock-runtime {:mvn/version "869.2.1687.0"}
                            'io.github.em-schmidt/bblf {:git/url "https://github.com/em-schmidt/bblf"
                                                        :git/sha "e08d9f7b40f8d4e65baa074c14743b6e62fc73b8"}}}))
      ;; Create uberjar
      (p/shell {:dir temp-path} "bb uberjar lambda.jar -m handler")
      (fs/move (str temp-path "/lambda.jar") dest-dir))))

(defn create-bootstrap [dest-dir handler-ref]
  (println "Creating bootstrap for handler:" handler-ref)
  (let [bootstrap-content (str "#!/bin/sh\n"
                               "set -e\n"
                               "cd ${LAMBDA_TASK_ROOT}\n"
                               "./bb -jar lambda.jar -m bblf.runtime " handler-ref "\n")]
    (spit (str dest-dir "/bootstrap") bootstrap-content)
    (fs/set-posix-file-permissions (str dest-dir "/bootstrap") "rwxr-xr-x")))

(defn build-function [function-name handler-ref]
  (println "\n=== Building" function-name "===")
  (let [function-dir (str "functions/" function-name)
        output-zip (str target-dir "/" function-name ".zip")]

    (when-not (fs/exists? target-dir)
      (fs/create-dir target-dir))

    (fs/with-temp-dir [tempdir {}]
      (let [dir (str tempdir)]
        ;; Fetch babashka binary
        (fetch-babashka dir)
        ;; Create uberjar with deps
        (prepare-uberjar function-dir dir)
        ;; Create bootstrap script
        (create-bootstrap dir handler-ref)
        ;; Create ZIP
        (println "Creating" output-zip "...")
        (fs/delete-if-exists output-zip)
        (fs/zip output-zip
                [(str dir)]
                {:root dir})))

    (println "Built:" output-zip)
    output-zip))

(def functions
  {"extract_metadata"            "handler/handler"
   "classify_document"           "handler/handler"
   "extract_entities"            "handler/handler"
   "generate_daily_summary"      "handler/handler"
   "generate_weekly_report"      "handler/handler"
   "update_classification_index" "handler/handler"})

(defn build-all []
  (println "Building all Lambda functions...\n")
  (doseq [[func-name handler-ref] functions]
    (build-function func-name handler-ref))
  (println "\n=== All builds complete ===")
  (println "Output files in" target-dir "/"))

(defn -main [& args]
  (let [func-name (first args)]
    (if func-name
      (if-let [handler-ref (get functions func-name)]
        (build-function func-name handler-ref)
        (do (println "Unknown function:" func-name)
            (println "Available:" (keys functions))
            (System/exit 1)))
      (build-all))))

(when (= *file* (System/getProperty "babashka.file"))
  (apply -main *command-line-args*))
