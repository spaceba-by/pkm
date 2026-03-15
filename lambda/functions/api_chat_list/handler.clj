(ns handler
  "API handler for GET /chat - list conversations for the authenticated user"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn- format-conversation [conv]
  {:id (:conversation_id conv)
   :title (:title conv)
   :created (r/truncate-timestamp (:created conv))
   :modified (r/truncate-timestamp (:modified conv))
   :messageCount (or (:message_count conv) 0)
   :status (or (:status conv) "active")})

(defn handler [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)
          conversations (ddb/query ddb-table
                                   :key-condition-expr "PK = :pk AND begins_with(SK, :sk)"
                                   :expr-attr-values {":pk" (str "user#" user-sub)
                                                      ":sk" "chat#"}
                                   :limit 50)
          ;; Sort by modified descending (most recent first)
          sorted (sort-by :modified #(compare %2 %1) conversations)
          formatted (mapv format-conversation sorted)]
      (r/ok-no-cache {:conversations formatted}))

    (catch Exception e
      (println "Error listing conversations:" (ex-message e))
      (r/internal-error "Failed to list conversations"))))
