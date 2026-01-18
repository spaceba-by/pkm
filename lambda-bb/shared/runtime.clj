(ns runtime
  "Minimal Lambda Runtime API handler for Babashka"
  (:require [babashka.http-client :as http]
            [cheshire.core :as json]))

(defn get-next-event
  "Fetch the next Lambda invocation from the Runtime API"
  [runtime-api]
  (let [url (str "http://" runtime-api "/2018-06-01/runtime/invocation/next")
        response (http/get url)]
    {:request-id (get (:headers response) "lambda-runtime-aws-request-id")
     :event (json/parse-string (:body response) true)}))

(defn send-response
  "Send successful response back to Lambda Runtime API"
  [runtime-api request-id response]
  (let [url (str "http://" runtime-api "/2018-06-01/runtime/invocation/" request-id "/response")
        body (if (string? response) response (json/generate-string response))]
    (http/post url {:body body})))

(defn send-error
  "Send error response back to Lambda Runtime API"
  [runtime-api request-id error-msg error-type]
  (let [url (str "http://" runtime-api "/2018-06-01/runtime/invocation/" request-id "/error")]
    (http/post url {:body (json/generate-string {:errorMessage error-msg
                                                  :errorType error-type})})))

(defn run-loop
  "Main runtime loop - continuously process Lambda invocations"
  [handler-fn]
  (let [runtime-api (System/getenv "AWS_LAMBDA_RUNTIME_API")]
    (println "Starting Lambda runtime loop, API:" runtime-api)
    (loop []
      (let [{:keys [request-id event]} (get-next-event runtime-api)]
        (try
          (let [response (handler-fn event nil)]
            (send-response runtime-api request-id response))
          (catch Exception e
            (println "Handler error:" (.getMessage e))
            (send-error runtime-api request-id (.getMessage e) (str (type e)))))
        (recur)))))
