(ns handler
  "Processing Lambda: execute one custom agent workflow run.

   Invoked asynchronously by workflow_dispatch (document, schedule and command
   triggers) and by api_workflows (manual runs). Loads the workflow definition,
   builds the template context from the vault, renders the prompt, invokes
   Bedrock, writes the output to the configured destination and records the
   run. Failures are recorded on the run record and returned as a 500 body;
   they are not rethrown because retries would re-spend tokens on a
   deterministic failure.

   Event (JSON):
     {\"workflow-id\": \"...\",
      \"trigger\": \"document\" | \"schedule\" | \"manual\" | \"command\",
      \"document-path\": \"optional S3 key\",
      \"command\": {\"name\": \"...\", \"args\": \"...\"},   ; command trigger
      \"run-id\": \"optional\"}"
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [aws.bedrock :as bedrock]
            [markdown.utils :as md]
            [workflow.engine :as engine]
            [workflow.schema :as schema]
            [workflow.triggers :as triggers]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.time Instant]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def s3-bucket (System/getenv "S3_BUCKET_NAME"))

(defn- model-env []
  (into {} (map (fn [v] [v (System/getenv v)]) (vals schema/models))))

;; =============================================================================
;; Loading
;; =============================================================================

(defn- load-workflow [workflow-id]
  (or (ddb/get-item ddb-table (schema/definition-key workflow-id))
      (throw (ex-info (str "Workflow not found: " workflow-id)
                      {:type :not-found :workflow-id workflow-id}))))

(defn- load-document
  "METADATA record and raw content for a single document"
  [document-path]
  (let [metadata (ddb/get-item ddb-table {:PK document-path :SK "METADATA"})
        content (try
                  (s3/get-object s3-bucket document-path)
                  (catch Exception e
                    (throw (ex-info (str "Document not readable: " document-path)
                                    {:type :not-found :document-path document-path}
                                    e))))]
    {:path document-path :metadata metadata :content content}))

(defn- load-document-set
  "Documents selected by the workflow filter within its lookback window, with
   bodies loaded from S3. Documents that fail to load are skipped with a log line."
  [workflow now]
  (let [wf-filter (:filter workflow)
        since (triggers/lookback-since wf-filter now)
        candidates (ddb/get-documents-modified-since ddb-table since)
        selected (triggers/select-documents wf-filter candidates)]
    (println "Selected" (count selected) "of" (count candidates) "documents modified since" since)
    (vec
     (keep (fn [doc]
             (let [path (:document_path doc)]
               (try
                 (let [content (s3/get-object s3-bucket path)
                       [_ body] (md/extract-frontmatter content)]
                   {:title (or (:title doc) (engine/title-from-path path))
                    :path path
                    :body (engine/truncate body engine/max-document-chars)})
                 (catch Exception e
                   (println "Skipping document that failed to load:" path "-" (ex-message e))
                   nil))))
           selected))))

;; =============================================================================
;; Execution
;; =============================================================================

(defn- write-output
  "Write the result to the configured destination. Returns the S3 key for the
   s3 destination, nil otherwise."
  [workflow ctx {:keys [run-id trigger document-path model-id now result]}]
  (let [destination (or (get-in workflow [:output :destination]) "s3")]
    (case destination
      "s3"
      (let [rendered (engine/render (schema/output-path-template workflow) ctx)
            key (engine/normalize-output-path rendered)
            doc (engine/render-output-document {:workflow-name (:name workflow)
                                                :run-id run-id
                                                :trigger trigger
                                                :document-path document-path
                                                :model-id model-id
                                                :generated-at now}
                                               result)]
        (s3/put-object s3-bucket key doc)
        (println "Wrote workflow output to" key)
        key)

      "dynamodb"
      nil

      "notification"
      (do
        (if (str/blank? (:created_by workflow))
          (println "Workflow has no created_by; skipping notification")
          (ddb/put-item ddb-table (schema/notification-record {:workflow workflow
                                                                :run-id run-id
                                                                :result result
                                                                :now now})))
        nil)

      (throw (ex-info (str "Unknown output destination: " destination)
                      {:type :validation :destination destination})))))

(defn- record-workflow-status
  [workflow-id now status]
  (ddb/update-item ddb-table (schema/definition-key workflow-id)
                   "SET last_run = :lr, last_status = :ls, updated = :u ADD run_count :one"
                   {":lr" now ":ls" status ":u" now ":one" 1}))

(defn execute-run
  "Run a workflow for the given event. Returns a summary map."
  [{:keys [workflow-id trigger document-path command run-id]}]
  (let [workflow (load-workflow workflow-id)
        trigger (or trigger "manual")
        run-id (or run-id (str (java.util.UUID/randomUUID)))
        start (Instant/now)
        started (str (.truncatedTo start java.time.temporal.ChronoUnit/SECONDS))
        run-key (schema/run-key workflow-id started run-id)]

    (when (and (not (triggers/enabled? workflow)) (not= trigger "manual"))
      (throw (ex-info (str "Workflow is disabled: " workflow-id)
                      {:type :skipped :workflow-id workflow-id})))

    (println "Executing workflow" (:name workflow) "run" run-id "trigger" trigger
             (when document-path (str "document " document-path)))

    ;; Claim the cooldown slot before doing any work so a duplicate event
    ;; arriving during this run is suppressed by the dispatcher.
    (when (and document-path (#{"document" "command"} trigger))
      (ddb/put-item ddb-table (schema/cooldown-record workflow-id document-path run-id started)))

    (let [document (when document-path (load-document document-path))
          documents (when-not document-path (load-document-set workflow start))
          ctx (engine/build-context {:workflow workflow
                                     :run-id run-id
                                     :document document
                                     :documents documents
                                     :command command
                                     :now start})]
      (ddb/put-item ddb-table (schema/run-record {:workflow workflow
                                                  :run-id run-id
                                                  :trigger trigger
                                                  :document-path document-path
                                                  :document-count (when documents (count documents))
                                                  :started started}))
      (try
        (let [prompt (:prompt workflow)
              model-id (schema/resolve-model-id prompt (model-env))
              rendered-system (engine/render (:system prompt) ctx)
              rendered-user (engine/render (:user prompt) ctx)
              _ (when (str/blank? rendered-user)
                  (throw (ex-info "Rendered prompt is empty" {:type :validation})))
              response (bedrock/invoke-model model-id rendered-user
                                             (schema/invoke-options prompt rendered-system))
              result (or (bedrock/extract-text response) "")
              usage (:usage response)
              now (schema/now-iso)
              output-key (write-output workflow ctx {:run-id run-id
                                                     :trigger trigger
                                                     :document-path document-path
                                                     :model-id model-id
                                                     :now now
                                                     :result result})
              duration-ms (- (System/currentTimeMillis) (.toEpochMilli start))]
          (ddb/update-item-attrs ddb-table run-key
                                 (schema/completion-attrs {:completed now
                                                           :duration-ms duration-ms
                                                           :model-id model-id
                                                           :usage usage
                                                           :output-s3-key output-key
                                                           :result result}))
          (record-workflow-status workflow-id now "completed")
          (println "Workflow run completed:" run-id "in" duration-ms "ms"
                   "tokens in/out" (:input_tokens usage) (:output_tokens usage))
          {:workflow-id workflow-id
           :run-id run-id
           :status "completed"
           :output-s3-key output-key
           :document-count (when documents (count documents))})

        (catch Exception e
          (let [now (schema/now-iso)
                duration-ms (- (System/currentTimeMillis) (.toEpochMilli start))]
            (println "Workflow run failed:" run-id "-" (ex-message e))
            (.printStackTrace e)
            (ddb/update-item-attrs ddb-table run-key
                                   (schema/failure-attrs {:completed now
                                                          :duration-ms duration-ms
                                                          :error (ex-message e)}))
            (record-workflow-status workflow-id now "failed")
            {:workflow-id workflow-id
             :run-id run-id
             :status "failed"
             :error (ex-message e)}))))))

(defn handler
  "Lambda handler for bblf runtime"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)]
      (println "Received workflow_execute event:" (json/generate-string event))
      (when (str/blank? (:workflow-id event))
        (throw (ex-info "Missing workflow-id" {:type :validation :event event})))
      (let [result (execute-run event)]
        {:statusCode (if (= "failed" (:status result)) 500 200)
         :body (json/generate-string result)}))

    (catch clojure.lang.ExceptionInfo e
      (let [data (ex-data e)]
        (case (:type data)
          :skipped (do (println "Skipping:" (ex-message e))
                       {:statusCode 200
                        :body (json/generate-string {:status "skipped" :message (ex-message e)})})
          (do (println "Error in workflow_execute:" (ex-message e))
              (.printStackTrace e)
              {:statusCode (if (= :not-found (:type data)) 404 400)
               :body (json/generate-string {:status "failed" :error (ex-message e)})}))))

    (catch Exception e
      (println "Error in workflow_execute:" (ex-message e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:status "failed" :error (ex-message e)})})))
