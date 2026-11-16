(ns handler
  "Processing Lambda: match events against custom agent workflow definitions
   and queue one workflow_execute invocation per match.

   Events (JSON):
     {\"trigger\": \"document\", \"document-path\": \"...\", \"bucket\": \"...\"}
         from classify_document after a document's classification is final
     {\"trigger\": \"command\", \"document-path\": \"...\", \"bucket\": \"...\",
      \"commands\": [{\"name\": \"...\", \"args\": \"...\", \"line-number\": n}]}
         from extract_metadata when a note contains @workflow:<name> lines
     {\"trigger\": \"schedule\"}
         from the EventBridge rate(15 minutes) rule"
  (:require [aws.dynamodb :as ddb]
            [aws.lambda :as lambda]
            [workflow.schema :as schema]
            [workflow.triggers :as triggers]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.time Instant]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def execute-fn (System/getenv "WORKFLOW_EXECUTE_FUNCTION_NAME"))

(defn- load-definitions []
  (ddb/query-all ddb-table
                 :key-condition-expr "PK = :pk"
                 :expr-attr-values {":pk" schema/definition-pk}))

(defn- queue-execution!
  [workflow trigger & opts]
  (when (str/blank? execute-fn)
    (throw (ex-info "WORKFLOW_EXECUTE_FUNCTION_NAME is not configured" {:type :config})))
  (let [event (apply schema/execute-event (:workflow_id workflow) trigger opts)]
    (lambda/invoke-async execute-fn event)
    (println "Queued workflow" (:name workflow) "trigger" trigger
             (when-let [p (:document-path event)] (str "document " p)))
    (:workflow_id workflow)))

(defn- cooling-down?
  "True when the (workflow, document) pair ran inside its cooldown window"
  [workflow document-path now]
  (let [marker (ddb/get-item ddb-table (schema/cooldown-key (:workflow_id workflow) document-path))
        blocked (triggers/in-cooldown? (:last_run marker) (:cooldown_minutes workflow) now)]
    (when blocked
      (println "Skipping workflow" (:name workflow) "for" document-path
               "- in cooldown since" (:last_run marker)))
    blocked))

;; =============================================================================
;; Triggers
;; =============================================================================

(defn dispatch-document
  "Queue every enabled document workflow whose filter matches the document"
  [document-path now]
  (let [doc (or (ddb/get-item ddb-table {:PK document-path :SK "METADATA"})
                {:document_path document-path})
        definitions (load-definitions)
        matched (triggers/document-workflows definitions doc)]
    (println "Document" document-path "matched" (count matched) "of" (count definitions) "workflows")
    (->> matched
         (remove #(cooling-down? % document-path now))
         (mapv #(queue-execution! % "document" :document-path document-path)))))

(defn dispatch-commands
  "Queue the workflow addressed by each @workflow:<name> command"
  [document-path commands now]
  (let [definitions (load-definitions)]
    (vec
     (keep (fn [{:keys [name args] :as command}]
             (if-let [workflow (triggers/find-command-workflow definitions name)]
               (when-not (cooling-down? workflow document-path now)
                 (queue-execution! workflow "command"
                                   :document-path document-path
                                   :command {:name (:name workflow) :args (or args "")}))
               (do (println "No enabled command workflow named" name "for" document-path
                            "line" (:line-number command))
                   nil)))
           commands))))

(defn- claim!
  "Advance next_run with a conditional update. Returns true when this
   invocation won the claim, false when another poll already did."
  [workflow now]
  (let [{:keys [update-expr expr-attr-values condition-expr extra-values]}
        (schema/claim-next-run workflow now)]
    (try
      (ddb/update-item ddb-table (schema/definition-key (:workflow_id workflow))
                       update-expr (merge expr-attr-values extra-values)
                       :condition-expr condition-expr)
      true
      (catch clojure.lang.ExceptionInfo e
        (if (= "ConditionalCheckFailedException" (:error-code (ex-data e)))
          (do (println "Workflow" (:name workflow) "already claimed by another poll") false)
          (throw e))))))

(defn dispatch-schedule
  "Queue every schedule workflow whose next_run has passed, claiming each first"
  [now]
  (let [definitions (load-definitions)
        due (triggers/due-workflows definitions now)]
    (println (count due) "of" (count definitions) "workflows due at" (str now))
    (->> due
         (filter #(claim! % now))
         (mapv #(queue-execution! % "schedule")))))

;; =============================================================================
;; Handler
;; =============================================================================

(defn handler
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          trigger (:trigger event)
          document-path (:document-path event)
          now (Instant/now)]
      (println "Received workflow_dispatch event:" (json/generate-string event))
      (let [queued (case trigger
                     "document"
                     (do (when (str/blank? document-path)
                           (throw (ex-info "Missing document-path" {:type :validation})))
                         (dispatch-document document-path now))

                     "command"
                     (do (when (str/blank? document-path)
                           (throw (ex-info "Missing document-path" {:type :validation})))
                         (dispatch-commands document-path (or (:commands event) []) now))

                     "schedule"
                     (dispatch-schedule now)

                     (throw (ex-info (str "Unknown trigger: " trigger) {:type :validation})))]
        {:statusCode 200
         :body (json/generate-string {:trigger trigger
                                      :queued (count queued)
                                      :workflowIds queued})}))

    (catch clojure.lang.ExceptionInfo e
      (println "Error in workflow_dispatch:" (ex-message e))
      (.printStackTrace e)
      {:statusCode (if (= :validation (:type (ex-data e))) 400 500)
       :body (json/generate-string {:error (ex-message e)})})

    (catch Exception e
      (println "Error in workflow_dispatch:" (ex-message e))
      (.printStackTrace e)
      {:statusCode 500
       :body (json/generate-string {:error (ex-message e)})})))
