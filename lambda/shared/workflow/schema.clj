(ns workflow.schema
  "Key layout, constants and record builders for custom agent workflows.

   Shared by the API, dispatch and execute Lambdas so every item written to
   DynamoDB has one definition. Pure functions only."
  (:require [clojure.string :as str]
            [workflow.engine :as engine])
  (:import [java.time Instant]
           [java.time.temporal ChronoUnit]))

;; =============================================================================
;; Keys
;; =============================================================================

(def definition-pk "workflow#def")

(defn definition-sk [workflow-id] (str "wf#" workflow-id))
(defn definition-key [workflow-id] {:PK definition-pk :SK (definition-sk workflow-id)})

(defn run-pk [workflow-id] (str "workflow#run#" workflow-id))
(defn run-sk [started run-id] (str "run#" started "#" run-id))
(defn run-key [workflow-id started run-id] {:PK (run-pk workflow-id) :SK (run-sk started run-id)})
(def run-sk-prefix "run#")

(defn cooldown-sk [document-path] (str "doc#" document-path))
(defn cooldown-key [workflow-id document-path]
  {:PK (run-pk workflow-id) :SK (cooldown-sk document-path)})

;; =============================================================================
;; Constants
;; =============================================================================

(def models
  "Logical model name -> environment variable holding the Bedrock model id"
  {"haiku" "BEDROCK_HAIKU_MODEL_ID"
   "sonnet" "BEDROCK_SONNET_MODEL_ID"})

(def destinations #{"s3" "dynamodb" "notification"})

(def default-model "haiku")
(def default-max-tokens 4096)
(def max-max-tokens 16000)
(def default-temperature 0.7)

(def max-stored-result-chars
  "Result text kept on the run record; the full text lives in S3 for s3 output"
  32000)

(def max-notification-body-chars 500)

(def run-statuses #{"running" "completed" "failed"})

(defn now-iso []
  (str (.truncatedTo (Instant/now) ChronoUnit/SECONDS)))

;; =============================================================================
;; Model resolution
;; =============================================================================

(defn resolve-model-id
  "Map a workflow's logical model name to a Bedrock model id using env, a map
   of environment variable name -> value. Throws ex-info {:type :validation}
   for an unknown name and {:type :config} when the id is not configured."
  [prompt env]
  (let [logical (or (:model prompt) default-model)
        env-var (get models logical)]
    (when-not env-var
      (throw (ex-info (str "Unknown model: " logical ". Expected one of: "
                           (str/join ", " (sort (keys models))))
                      {:type :validation :model logical})))
    (let [model-id (get env env-var)]
      (when (str/blank? model-id)
        (throw (ex-info (str "Model id not configured: " env-var)
                        {:type :config :model logical :env-var env-var})))
      model-id)))

(defn invoke-options
  "Bedrock invoke options for a workflow prompt, with defaults and caps applied"
  [prompt rendered-system]
  (cond-> {:max-tokens (-> (or (:max_tokens prompt) default-max-tokens)
                           (max 1)
                           (min max-max-tokens))
           :temperature (or (:temperature prompt) default-temperature)}
    (not (str/blank? rendered-system)) (assoc :system rendered-system)))

;; =============================================================================
;; Records
;; =============================================================================

(defn truncate-result
  [result]
  (let [result (or result "")]
    (if (> (count result) max-stored-result-chars)
      (str (subs result 0 max-stored-result-chars) "\n\n[... truncated; see output file ...]")
      result)))

(defn run-record
  "Initial run record, status running"
  [{:keys [workflow run-id trigger document-path document-count started]}]
  (cond-> {:PK (run-pk (:workflow_id workflow))
           :SK (run-sk started run-id)
           :run_id run-id
           :workflow_id (:workflow_id workflow)
           :workflow_name (:name workflow)
           :trigger trigger
           :status "running"
           :started started}
    document-path (assoc :document_path document-path)
    (some? document-count) (assoc :document_count document-count)))

(defn completion-attrs
  "Attributes set on the run record when a run finishes successfully"
  [{:keys [completed duration-ms model-id usage output-s3-key result]}]
  (cond-> {:status "completed"
           :completed completed
           :duration_ms duration-ms
           :model_id model-id
           :result (truncate-result result)}
    (:input_tokens usage) (assoc :input_tokens (:input_tokens usage))
    (:output_tokens usage) (assoc :output_tokens (:output_tokens usage))
    output-s3-key (assoc :output_s3_key output-s3-key)))

(defn failure-attrs
  "Attributes set on the run record when a run fails"
  [{:keys [completed duration-ms error]}]
  {:status "failed"
   :completed completed
   :duration_ms duration-ms
   :error (or error "Unknown error")})

(defn cooldown-record
  [workflow-id document-path run-id now]
  (merge (cooldown-key workflow-id document-path)
         {:workflow_id workflow-id
          :document_path document-path
          :run_id run-id
          :last_run now}))

(defn notification-record
  "Notification item for the workflow creator, delivered by notification_dispatch"
  [{:keys [workflow run-id result now]}]
  (let [notification-id (str (java.util.UUID/randomUUID))
        body (-> (or result "") str/trim)
        body (if (> (count body) max-notification-body-chars)
               (str (subs body 0 max-notification-body-chars) "…")
               body)]
    {:PK (str "user#" (:created_by workflow))
     :SK (str "notification#pending#" now "#" notification-id)
     :notification_id notification-id
     :notification_type "workflow"
     :title (str "Workflow: " (:name workflow))
     :body body
     :deep_link (str "/workflows/" (:workflow_id workflow) "/runs/" run-id)
     :timestamp now
     :read false}))

(defn output-path-template
  "The workflow's output path template, or the default"
  [workflow]
  (let [template (get-in workflow [:output :path])]
    (if (str/blank? template) engine/default-output-path template)))

;; =============================================================================
;; API formatting (snake_case items -> camelCase responses)
;; =============================================================================

(defn format-run
  [run]
  (cond-> {:runId (:run_id run)
           :workflowId (:workflow_id run)
           :workflowName (:workflow_name run)
           :trigger (:trigger run)
           :status (:status run)
           :started (:started run)}
    (:document_path run) (assoc :documentPath (:document_path run))
    (some? (:document_count run)) (assoc :documentCount (:document_count run))
    (:completed run) (assoc :completed (:completed run))
    (some? (:duration_ms run)) (assoc :durationMs (:duration_ms run))
    (:model_id run) (assoc :modelId (:model_id run))
    (some? (:input_tokens run)) (assoc :inputTokens (:input_tokens run))
    (some? (:output_tokens run)) (assoc :outputTokens (:output_tokens run))
    (:output_s3_key run) (assoc :outputS3Key (:output_s3_key run))
    (:result run) (assoc :result (:result run))
    (:error run) (assoc :error (:error run))))
