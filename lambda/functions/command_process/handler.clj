(ns handler
  "Lambda function to process chat messages and @sal commands.
   Loads conversation history, builds PKM context, invokes Bedrock Claude
   for reasoning, and stores the response."
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [aws.bedrock :as bedrock]
            [command.context :as context]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def model-id (System/getenv "BEDROCK_MODEL_ID"))

(def ^:private system-prompt
  "You are a knowledgeable assistant for a Personal Knowledge Management (PKM) system.
You have access to the user's vault of markdown documents, including their notes,
meeting records, ideas, journal entries, and project plans.

Your role is to:
- Answer questions about the user's knowledge base
- Find connections between documents and concepts
- Summarize information across multiple documents
- Provide insights and recommendations based on the user's notes

When responding:
- Reference specific documents by their titles when relevant
- Be concise but thorough
- If you don't have enough context to answer, say so
- Format responses in markdown")

(def ^:private max-history-messages 20)

(defn- load-conversation-history
  "Load recent messages for a conversation, returns messages in chronological order"
  [conversation-id]
  (try
    (let [[messages _] (ddb/query-to-limit ddb-table
                                            :key-condition-expr "PK = :pk AND begins_with(SK, :sk)"
                                            :expr-attr-values {":pk" (str "chat#" conversation-id)
                                                               ":sk" "msg#"}
                                            :limit max-history-messages
                                            :scan-index-forward true)]
      messages)
    (catch Exception e
      (println "Error loading conversation history:" (ex-message e))
      [])))

(defn- build-messages
  "Build the messages array for Bedrock from conversation history"
  [history]
  (->> history
       (filter #(and (:role %) (:content %)
                     (#{"user" "assistant"} (:role %))
                     (= "complete" (:status %))))
       (mapv (fn [msg]
               {:role (:role msg)
                :content (:content msg)}))))

(defn- store-message
  "Store a message in DynamoDB"
  [conversation-id message-id role content status]
  (let [now (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS))
        sk (str "msg#" now "#" message-id)]
    (ddb/put-item ddb-table
                  {:PK (str "chat#" conversation-id)
                   :SK sk
                   :message_id message-id
                   :role role
                   :content content
                   :timestamp now
                   :status status})))

(defn- update-message-status
  "Update the status and content of an existing message"
  [conversation-id message-id content status]
  ;; Query to find the message's SK
  (let [[messages _] (ddb/query-to-limit ddb-table
                                          :key-condition-expr "PK = :pk AND begins_with(SK, :sk)"
                                          :expr-attr-values {":pk" (str "chat#" conversation-id)
                                                             ":sk" "msg#"}
                                          :limit 100
                                          :scan-index-forward false)]
    (when-let [msg (first (filter #(= message-id (:message_id %)) messages))]
      (ddb/update-item-attrs ddb-table
                              {:PK (str "chat#" conversation-id) :SK (:SK msg)}
                              (cond-> {:status status}
                                content (assoc :content content))))))

(defn- update-conversation
  "Update conversation metadata after a new message"
  [user-sub conversation-id]
  (let [now (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS))]
    (try
      (ddb/update-item-attrs ddb-table
                              {:PK (str "user#" user-sub) :SK (str "chat#" conversation-id)}
                              {:modified now})
      (catch Exception e
        (println "Error updating conversation:" (ex-message e))))))

(defn- write-sal-response
  "Write @sal command response to S3"
  [document-path command-text response-text]
  (let [now (str (.truncatedTo (java.time.Instant/now) java.time.temporal.ChronoUnit/SECONDS))
        doc-base (str/replace document-path #"\.md$" "")
        s3-key (str "_agent/responses/" doc-base "/" now ".md")
        content (str "---\n"
                     "command: \"" command-text "\"\n"
                     "source_document: " document-path "\n"
                     "generated_at: " now "\n"
                     "---\n\n"
                     "# Response to: " command-text "\n\n"
                     response-text "\n")]
    (s3/put-object s3-bucket s3-key content)
    (println "Wrote @sal response to:" s3-key)
    ;; Track in DynamoDB
    (ddb/put-item ddb-table
                  {:PK document-path
                   :SK (str "COMMAND_RESPONSE#" now)
                   :command_text command-text
                   :response_s3_key s3-key
                   :status "complete"
                   :created now})
    s3-key))

(defn- process-chat-message
  "Process a chat message: build context, invoke Bedrock, store response"
  [{:keys [conversation-id assistant-message-id user-sub]}]
  (try
    (println "Processing chat message for conversation:" conversation-id)

    ;; Load conversation history
    (let [history (load-conversation-history conversation-id)
          messages (build-messages history)]

      (when (empty? messages)
        (throw (ex-info "No messages found in conversation" {:conversation-id conversation-id})))

      ;; Build PKM context from the latest user message
      (let [last-user-msg (last (filter #(= "user" (:role %)) messages))
            command-text (:content last-user-msg)
            pkm-context (context/build-context ddb-table s3-bucket command-text)
            full-system (str system-prompt "\n\nBelow is context from the user's PKM vault:\n<context>\n"
                             pkm-context "\n</context>")
            response (bedrock/invoke-model-multi-turn model-id messages
                                                       {:system full-system})
            response-text (bedrock/extract-text response)]

        ;; Update the pending assistant message with the response
        (update-message-status conversation-id assistant-message-id response-text "complete")
        (update-conversation user-sub conversation-id)

        (println "Chat response generated for conversation:" conversation-id)
        response-text))
    (catch Exception e
      (println "Error processing chat message:" (ex-message e))
      ;; Mark message as error
      (try
        (update-message-status conversation-id assistant-message-id
                                (str "I'm sorry, I encountered an error processing your request. Please try again.")
                                "error")
        (catch Exception _))
      nil)))

(defn- process-sal-command
  "Process an @sal command from a document"
  [{:keys [document-path commands]}]
  (println "Processing @sal commands from:" document-path "count:" (count commands))
  (doseq [{:keys [command]} commands]
    (try
      (let [pkm-context (context/build-context ddb-table s3-bucket command)
            full-system (str system-prompt "\n\nBelow is context from the user's PKM vault:\n<context>\n"
                             pkm-context "\n</context>")
            prompt (str "Command from document '" document-path "': " command)
            response (bedrock/invoke-model model-id prompt
                                            {:max-tokens 4096
                                             :temperature 0.7
                                             :system full-system})
            response-text (bedrock/extract-text response)]
        (write-sal-response document-path command response-text))
      (catch Exception e
        (println "Error processing @sal command:" command "error:" (ex-message e))))))

(defn handler
  "Lambda handler - processes both chat messages and @sal commands"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)]
      (println "Received command_process event:" (json/generate-string event))

      (cond
        ;; Chat message processing
        (:conversation-id event)
        (do
          (process-chat-message event)
          {:statusCode 200
           :body (json/generate-string {:status "processed"})})

        ;; @sal command processing
        (:document-path event)
        (do
          (process-sal-command event)
          {:statusCode 200
           :body (json/generate-string {:status "processed"
                                        :document (:document-path event)})})

        :else
        {:statusCode 400
         :body (json/generate-string {:error "Unknown event type"})}))

    (catch Exception e
      (println "Error in command_process handler:" (ex-message e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:error (ex-message e)})})))
