(ns handler
  "API handler for GET /chat/{conversationId} - get messages for a conversation"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn- format-message [msg]
  {:id (:message_id msg)
   :role (:role msg)
   :content (:content msg)
   :timestamp (r/truncate-timestamp (:timestamp msg))
   :status (or (:status msg) "complete")})

(defn handler [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)
          path-params (r/parse-path-params event)
          conversation-id (or (:conversationId path-params)
                              (get path-params "conversationId"))]

      (when (or (nil? conversation-id) (clojure.string/blank? conversation-id))
        (throw (ex-info "Conversation ID is required" {:type :validation})))

      ;; Verify the conversation belongs to this user
      (let [conversation (ddb/get-item ddb-table
                                        {:PK (str "user#" user-sub)
                                         :SK (str "chat#" conversation-id)})]
        (when-not conversation
          (throw (ex-info "Conversation not found" {:type :not-found})))

        ;; Get messages in chronological order
        (let [messages (ddb/query ddb-table
                                  :key-condition-expr "PK = :pk AND begins_with(SK, :sk)"
                                  :expr-attr-values {":pk" (str "chat#" conversation-id)
                                                     ":sk" "msg#"}
                                  :limit 100
                                  :scan-index-forward true)
              formatted (mapv format-message messages)]
          (r/ok-no-cache {:conversationId conversation-id
                          :messages formatted}))))

    (catch clojure.lang.ExceptionInfo e
      (case (:type (ex-data e))
        :validation (r/bad-request (ex-message e))
        :not-found (r/not-found (ex-message e))
        (do
          (println "Error getting messages:" (ex-message e))
          (r/internal-error "Failed to get messages"))))
    (catch Exception e
      (println "Error getting messages:" (ex-message e))
      (r/internal-error "Failed to get messages"))))
