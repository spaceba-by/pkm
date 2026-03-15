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
(require '[search.vector-index-test])
(require '[search.chunker-test])
(require '[search.semantic-test])
(require '[api.write-handlers-test])
(require '[api.graph-data-test])
(require '[shared.secrets-manager-test])
(require '[notifications.handler-test])
(require '[insights.viewed-test])
(require '[webhooks.utils-test])
(require '[command.parser-test])
(require '[command.context-test])
(require '[tasks.extractor-test])
(require '[tasks.api-test])

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
                 'persistent-search.api-test
                 'search.vector-index-test
                 'search.chunker-test
                 'search.semantic-test
                 'api.write-handlers-test
                 'api.graph-data-test
                 'shared.secrets-manager-test
                 'notifications.handler-test
                 'insights.viewed-test
                 'webhooks.utils-test
                 'command.parser-test
                 'command.context-test
                 'tasks.extractor-test
                 'tasks.api-test)]
    (when (or (pos? (:fail summary))
              (pos? (:error summary)))
      (System/exit 1))))
