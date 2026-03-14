(ns handler
  "API handler for POST /chat - send a chat message.
   Creates conversation if needed, stores user message, creates pending
   assistant message, invokes command_process async, returns 202."
  (:require [aws.dynamodb :as ddb]
            [aws.lambda :as lambda]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def command-process-fn (System/getenv "COMMAND_PROCESS_FUNCTION_NAME"))

(defn- generate-id []
  (str (java.util.UUID/randomUUID)))

(defn- now-iso []
  (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS)))

(defn- create-conversation
  "Create a new conversation record"
  [user-sub conversation-id title]
  (let [now (now-iso)]
    (ddb/put-item ddb-table
                  {:PK (str "user#" user-sub)
                   :SK (str "chat#" conversation-id)
                   :conversation_id conversation-id
                   :title title
                   :created now
                   :modified now
                   :message_count 0
                   :status "active"})))

(defn- store-message
  "Store a message in DynamoDB"
  [conversation-id message-id role content status]
  (let [now (now-iso)]
    (ddb/put-item ddb-table
                  {:PK (str "chat#" conversation-id)
                   :SK (str "msg#" now "#" message-id)
                   :message_id message-id
                   :role role
                   :content content
                   :timestamp now
                   :status status})))

(defn- generate-title
  "Generate a short title from the first message"
  [message]
  (let [words (clojure.string/split message #"\s+")
        title (clojure.string/join " " (take 6 words))]
    (if (> (count words) 6)
      (str title "...")
      title)))

(defn handler [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)
          body (when-let [b (or (:body event) (get event "body"))]
                 (if (string? b) (json/parse-string b true) b))
          message (:message body)
          conversation-id (or (:conversationId body) (generate-id))
          is-new (nil? (:conversationId body))]

      ;; Validate
      (when (or (nil? message) (clojure.string/blank? message))
        (throw (ex-info "Message is required" {:type :validation})))

      ;; Create conversation if new
      (when is-new
        (create-conversation user-sub conversation-id (generate-title message)))

      ;; Store user message
      (let [user-msg-id (generate-id)
            assistant-msg-id (generate-id)]
        (store-message conversation-id user-msg-id "user" message "complete")

        ;; Store pending assistant message
        (store-message conversation-id assistant-msg-id "assistant" "" "pending")

        ;; Invoke command_process async
        (lambda/invoke-async command-process-fn
                             {:conversation-id conversation-id
                              :assistant-message-id assistant-msg-id
                              :user-sub user-sub})

        ;; Return 202 Accepted
        (r/accepted {:conversationId conversation-id
                     :userMessage {:id user-msg-id
                                   :role "user"
                                   :content message
                                   :timestamp (now-iso)
                                   :status "complete"}
                     :assistantMessageId assistant-msg-id})))

    (catch clojure.lang.ExceptionInfo e
      (if (= :validation (:type (ex-data e)))
        (r/bad-request (ex-message e))
        (do
          (println "Error in chat send:" (ex-message e))
          (r/internal-error "Failed to send message"))))
    (catch Exception e
      (println "Error in chat send:" (ex-message e))
      (r/internal-error "Failed to send message"))))
