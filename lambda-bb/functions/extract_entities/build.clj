#!/usr/bin/env bb

(require '[babashka.fs :as fs]
         '[babashka.process :refer [shell]])

(def function-name "extract_entities")
(def handler-ns "extract-entities.handler")

(println "Building" function-name "lambda...")

;; Clean previous build
(when (fs/exists? "bootstrap")
  (fs/delete "bootstrap"))
(when (fs/exists? (str function-name ".zip"))
  (fs/delete (str function-name ".zip")))

;; Create bootstrap script
(spit "bootstrap"
      (str "#!/bin/sh\n"
           "exec bb -cp $(dirname $0) -m " handler-ns " handler\n"))

;; Make bootstrap executable
(fs/set-posix-file-permissions "bootstrap" "rwxr-xr-x")

;; Package lambda
(shell "zip -r" (str function-name ".zip") "bootstrap" "bb.edn" "handler.clj" "../../shared")

(println "Build complete:" (str function-name ".zip"))
