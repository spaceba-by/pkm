(ns workflow.schema
  "Key layout, constants and record builders for custom agent workflows.

   Shared by the API, dispatch and execute Lambdas so every item written to
   DynamoDB has one definition. Pure functions only."
  (:require [clojure.string :as str]
            [workflow.engine :as engine]
            [workflow.triggers :as triggers])
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

;; =============================================================================
;; Definition validation and API conversion
;; =============================================================================

(def name-pattern #"^[a-z0-9][a-z0-9-]{1,63}$")
(def valid-classifications #{"meeting" "idea" "reference" "journal" "project"})
(def max-lookback-days 90)
(def max-cooldown-minutes 10080) ;; one week

(defn- present? [m k] (and (map? m) (contains? m k)))

(defn body->definition
  "Convert a camelCase API body into the snake_case definition shape. Only
   keys present in the body appear in the result, so the same function serves
   create and partial update."
  [body]
  (let [sub (fn [m pairs]
              (reduce (fn [acc [from to]]
                        (if (present? m from) (assoc acc to (get m from)) acc))
                      {} pairs))
        trigger (when (present? body :trigger)
                  (let [t (:trigger body)]
                    (cond-> (sub t [[:type :type]])
                      (present? t :schedule)
                      (assoc :schedule (sub (:schedule t) [[:frequency :frequency]
                                                           [:minute :minute]
                                                           [:hour :hour]
                                                           [:dayOfWeek :day_of_week]])))))
        wf-filter (when (present? body :filter)
                    (sub (:filter body) [[:pathPrefix :path_prefix]
                                         [:tags :tags]
                                         [:classifications :classifications]
                                         [:lookbackDays :lookback_days]]))
        prompt (when (present? body :prompt)
                 (sub (:prompt body) [[:system :system]
                                      [:user :user]
                                      [:model :model]
                                      [:maxTokens :max_tokens]
                                      [:temperature :temperature]]))
        output (when (present? body :output)
                 (sub (:output body) [[:destination :destination]
                                      [:path :path]]))]
    (cond-> (sub body [[:name :name]
                       [:description :description]
                       [:enabled :enabled]
                       [:cooldownMinutes :cooldown_minutes]])
      trigger (assoc :trigger trigger)
      wf-filter (assoc :filter wf-filter)
      prompt (assoc :prompt prompt)
      output (assoc :output output))))

(defn apply-defaults
  "Fill defaults for optional fields of a complete definition"
  [definition]
  (-> definition
      (update :description #(or % ""))
      (update :enabled #(if (nil? %) true %))
      (update :cooldown_minutes #(or % triggers/default-cooldown-minutes))
      (update :filter #(or % {}))
      (update :prompt (fn [p] (merge {:model default-model
                                      :max_tokens default-max-tokens
                                      :temperature default-temperature}
                                     p)))
      (update :output (fn [o] (merge {:destination "s3"} o)))))

(defn- string-list? [v] (and (sequential? v) (every? string? v)))

(defn validate-definition
  "Validate a complete snake_case definition. other-names is the set of names
   already used by other workflows. Returns a vector of error messages; empty
   when valid."
  [{:keys [name description enabled trigger filter prompt output cooldown_minutes]} other-names]
  (let [errors (transient [])
        err! (fn [msg] (conj! errors msg))
        taken (set (map str/lower-case (or other-names [])))]
    ;; name / description / enabled / cooldown
    (cond
      (not (string? name)) (err! "name is required")
      (not (re-matches name-pattern name)) (err! "name must be 2-64 lower-case letters, digits or hyphens, starting with a letter or digit")
      (contains? taken (str/lower-case name)) (err! (str "name is already in use: " name)))
    (when (and (some? description) (not (string? description)))
      (err! "description must be a string"))
    (when (and (some? enabled) (not (boolean? enabled)))
      (err! "enabled must be a boolean"))
    (when (and (some? cooldown_minutes)
               (not (and (integer? cooldown_minutes) (<= 0 cooldown_minutes max-cooldown-minutes))))
      (err! (str "cooldownMinutes must be an integer from 0 to " max-cooldown-minutes)))
    ;; trigger
    (let [type (:type trigger)]
      (cond
        (not (map? trigger)) (err! "trigger is required")
        (not (triggers/trigger-types type)) (err! (str "trigger.type must be one of: " (str/join ", " (sort triggers/trigger-types))))
        (= "schedule" type) (doseq [e (triggers/validate-schedule (:schedule trigger))] (err! (str "trigger.schedule: " e)))))
    ;; filter
    (when (some? filter)
      (if-not (map? filter)
        (err! "filter must be an object")
        (let [{:keys [path_prefix tags classifications lookback_days]} filter]
          (when (and (some? path_prefix) (not (string? path_prefix)))
            (err! "filter.pathPrefix must be a string"))
          (when (and (some? tags) (not (string-list? tags)))
            (err! "filter.tags must be a list of strings"))
          (when (some? classifications)
            (if-not (string-list? classifications)
              (err! "filter.classifications must be a list of strings")
              (doseq [c (remove valid-classifications classifications)]
                (err! (str "filter.classifications contains unknown value: " c)))))
          (when (and (some? lookback_days)
                     (not (and (integer? lookback_days) (<= 1 lookback_days max-lookback-days))))
            (err! (str "filter.lookbackDays must be an integer from 1 to " max-lookback-days))))))
    ;; prompt
    (if-not (map? prompt)
      (err! "prompt is required")
      (let [{:keys [system user model max_tokens temperature]} prompt]
        (if (or (not (string? user)) (str/blank? user))
          (err! "prompt.user is required")
          (doseq [e (engine/validate-template user)] (err! (str "prompt.user: " e))))
        (when (some? system)
          (if-not (string? system)
            (err! "prompt.system must be a string")
            (doseq [e (engine/validate-template system)] (err! (str "prompt.system: " e)))))
        (when (and (some? model) (not (contains? models model)))
          (err! (str "prompt.model must be one of: " (str/join ", " (sort (keys models))))))
        (when (and (some? max_tokens)
                   (not (and (integer? max_tokens) (<= 1 max_tokens max-max-tokens))))
          (err! (str "prompt.maxTokens must be an integer from 1 to " max-max-tokens)))
        (when (and (some? temperature)
                   (not (and (number? temperature) (<= 0 temperature 1))))
          (err! "prompt.temperature must be a number from 0 to 1"))))
    ;; output
    (when (some? output)
      (if-not (map? output)
        (err! "output must be an object")
        (let [{:keys [destination path]} output]
          (when (and (some? destination) (not (destinations destination)))
            (err! (str "output.destination must be one of: " (str/join ", " (sort destinations)))))
          (when (some? path)
            (cond
              (not (string? path)) (err! "output.path must be a string")
              (str/blank? path) nil
              (not (engine/output-path-template-allowed? path)) (err! (str "output.path must start with " engine/output-root))
              :else (doseq [e (engine/validate-template path)] (err! (str "output.path: " e))))))))
    (persistent! errors)))

(defn format-definition
  "Format a definition item for API responses"
  [item]
  (let [trigger (:trigger item)
        schedule (:schedule trigger)
        wf-filter (:filter item)
        prompt (:prompt item)
        output (:output item)]
    (cond-> {:id (:workflow_id item)
             :name (:name item)
             :description (or (:description item) "")
             :enabled (boolean (:enabled item))
             :trigger (cond-> {:type (:type trigger)}
                        schedule (assoc :schedule (cond-> {:frequency (:frequency schedule)}
                                                    (some? (:minute schedule)) (assoc :minute (:minute schedule))
                                                    (some? (:hour schedule)) (assoc :hour (:hour schedule))
                                                    (:day_of_week schedule) (assoc :dayOfWeek (:day_of_week schedule)))))
             :filter (cond-> {}
                       (:path_prefix wf-filter) (assoc :pathPrefix (:path_prefix wf-filter))
                       (:tags wf-filter) (assoc :tags (:tags wf-filter))
                       (:classifications wf-filter) (assoc :classifications (:classifications wf-filter))
                       (:lookback_days wf-filter) (assoc :lookbackDays (:lookback_days wf-filter)))
             :prompt (cond-> {:user (:user prompt)
                              :model (or (:model prompt) default-model)
                              :maxTokens (or (:max_tokens prompt) default-max-tokens)
                              :temperature (or (:temperature prompt) default-temperature)}
                       (:system prompt) (assoc :system (:system prompt)))
             :output (cond-> {:destination (or (:destination output) "s3")}
                       (:path output) (assoc :path (:path output)))
             :cooldownMinutes (or (:cooldown_minutes item) triggers/default-cooldown-minutes)
             :runCount (or (:run_count item) 0)
             :created (:created item)
             :updated (:updated item)}
      (:next_run item) (assoc :nextRun (:next_run item))
      (:last_run item) (assoc :lastRun (:last_run item))
      (:last_status item) (assoc :lastStatus (:last_status item))
      (:created_by item) (assoc :createdBy (:created_by item)))))
