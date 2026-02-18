(ns test-runner
  "Test runner for Babashka tests"
  (:require [clojure.test :as t]))

;; Require all test namespaces
(require '[shared.markdown.utils-test])
(require '[api.response-test])
(require '[api.handlers-test])
(require '[shared.classification-test])
(require '[shared.deletion-test])
(require '[delete-document.handler-test])
(require '[persistent-search.execute-test])
(require '[persistent-search.summarizer-test])
(require '[persistent-search.api-test])

(defn -main [& args]
  (let [summary (t/run-tests
                 'shared.markdown.utils-test
                 'api.response-test
                 'api.handlers-test
                 'shared.classification-test
                 'shared.deletion-test
                 'delete-document.handler-test
                 'persistent-search.execute-test
                 'persistent-search.summarizer-test
                 'persistent-search.api-test)]
    (when (or (pos? (:fail summary))
              (pos? (:error summary)))
      (System/exit 1))))
