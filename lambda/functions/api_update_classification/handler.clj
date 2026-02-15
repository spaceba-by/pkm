(ns handler
  "API Lambda: Update document classification (manual override)"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(def valid-classifications
  #{"meeting" "idea" "reference" "journal" "project"})

(defn handler
  "Lambda handler for PUT /documents/{key+}/classification"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)
          path-params (r/parse-path-params event)
          document-key (or (:key path-params) (get path-params "key"))

          ;; Parse request body
          request-body (when-let [body (or (:body event) (get event "body"))]
                         (if (string? body)
                           (json/parse-string body true)
                           body))
          classification (some-> (:classification request-body)
                                 clojure.string/trim
                                 clojure.string/lower-case)]

      (println "User" user-sub "updating classification for" document-key
               "to" classification)

      ;; Validate inputs
      (cond
        (nil? document-key)
        (r/bad-request "Missing document key")

        (nil? classification)
        (r/bad-request "Missing classification in request body")

        (not (valid-classifications classification))
        (r/bad-request (str "Invalid classification. Must be one of: "
                           (clojure.string/join ", " (sort valid-classifications))))

        :else
        ;; Verify document exists
        (let [existing (ddb/get-item ddb-table {:PK document-key :SK "METADATA"})]
          (if (nil? existing)
            (r/not-found (str "Document not found: " document-key))

            ;; Update classification with override flag
            (let [now (str (java.time.Instant/now))
                  updated (ddb/update-item
                            ddb-table
                            {:PK document-key :SK "METADATA"}
                            "SET classification = :c, classification_override = :o, classification_overridden_at = :t, modified = :m"
                            {":c" classification
                             ":o" true
                             ":t" now
                             ":m" now})]
              (r/ok-no-cache {:document document-key
                              :classification classification
                              :classification_override true
                              :updated_at now}))))))

    (catch Exception e
      (println "Error updating classification:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to update classification"))))
