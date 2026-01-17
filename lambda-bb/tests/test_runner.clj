(ns test-runner
  "Test runner for Babashka tests"
  (:require [clojure.test :as t]))

;; Require all test namespaces
(require '[shared.markdown.utils-test])

(defn -main [& args]
  (let [summary (t/run-tests 'shared.markdown.utils-test)]
    (when (or (pos? (:fail summary))
              (pos? (:error summary)))
      (System/exit 1))))
