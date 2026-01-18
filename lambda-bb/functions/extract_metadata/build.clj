#!/usr/bin/env bb

(require '[babashka.fs :as fs]
         '[babashka.process :refer [shell]])

(def function-name "extract_metadata")

(println "Building" function-name "lambda...")

;; Clean previous build
(when (fs/exists? "bootstrap")
  (fs/delete "bootstrap"))
(when (fs/exists? (str function-name ".zip"))
  (fs/delete (str function-name ".zip")))

;; Create bootstrap script
(spit "bootstrap"
"#!/bin/sh
set -e
cd /var/task
exec /opt/bin/bb -cp .:/var/task/shared -e '(require (quote runtime) (quote handler)) (runtime/run-loop handler/handler)'
")

;; Make bootstrap executable
(fs/set-posix-file-permissions "bootstrap" "rwxr-xr-x")

;; Package lambda
(shell "zip -r" (str function-name ".zip") "bootstrap" "bb.edn" "handler.clj" "../../shared")

(println "Build complete:" (str function-name ".zip"))
