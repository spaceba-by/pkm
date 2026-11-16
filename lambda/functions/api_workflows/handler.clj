(ns handler
  "API Lambda: custom agent workflow definitions and runs.
     GET    /workflows              list definitions
     POST   /workflows              create (admin)
     GET    /workflows/{id}         definition with recent runs
     PUT    /workflows/{id}         partial update (admin)
     DELETE /workflows/{id}         delete definition, runs and cooldown markers (admin)
     POST   /workflows/{id}/run     manual run (admin), 202 with runId
     GET    /workflows/{id}/runs    run history, newest first, cursor paginated"
  (:require [aws.dynamodb :as ddb]
            [aws.lambda :as lambda]
            [api.response :as r]
            [workflow.schema :as schema]
            [workflow.triggers :as triggers]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.time Instant]
           [java.util Base64]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def execute-fn (System/getenv "WORKFLOW_EXECUTE_FUNCTION_NAME"))

(def recent-runs-limit 5)
(def default-runs-limit 20)
(def max-runs-limit 100)

;; =============================================================================
;; Helpers
;; =============================================================================

(defn encode-cursor [last-key]
  (when last-key
    (.encodeToString (Base64/getUrlEncoder)
                     (.getBytes (json/generate-string last-key) "UTF-8"))))

(defn decode-cursor [cursor]
  (when-not (str/blank? cursor)
    (try
      (json/parse-string (String. (.decode (Base64/getUrlDecoder) cursor) "UTF-8") true)
      (catch Exception _ nil))))

(defn- validation-error [errors]
  (throw (ex-info (str/join "; " errors) {:type :validation :errors errors})))

(defn- load-definition [workflow-id]
  (or (ddb/get-item ddb-table (schema/definition-key workflow-id))
      (throw (ex-info (str "Workflow not found: " workflow-id) {:type :not-found}))))

(defn- list-definitions []
  (ddb/query-all ddb-table
                 :key-condition-expr "PK = :pk"
                 :expr-attr-values {":pk" schema/definition-pk}))

(defn- other-names [definitions workflow-id]
  (->> definitions
       (remove #(= workflow-id (:workflow_id %)))
       (map :name)
       set))

(defn- with-next-run
  "Set next_run for schedule triggers, clear it otherwise"
  [definition now]
  (if (= "schedule" (get-in definition [:trigger :type]))
    (assoc definition :next_run (triggers/next-run (get-in definition [:trigger :schedule]) now))
    (dissoc definition :next_run)))

(defn- query-runs [workflow-id limit start-key]
  (ddb/query-to-limit ddb-table
                      :key-condition-expr "PK = :pk AND begins_with(SK, :prefix)"
                      :expr-attr-values {":pk" (schema/run-pk workflow-id)
                                         ":prefix" schema/run-sk-prefix}
                      :limit limit
                      :scan-index-forward false
                      :exclusive-start-key start-key))

;; =============================================================================
;; Operations
;; =============================================================================

(defn- list-workflows []
  (let [items (sort-by :name (list-definitions))]
    (r/ok-no-cache {:workflows (mapv schema/format-definition items)
                    :count (count items)})))

(defn- get-workflow [workflow-id]
  (let [definition (load-definition workflow-id)
        [runs _] (query-runs workflow-id recent-runs-limit nil)]
    (r/ok-no-cache (assoc (schema/format-definition definition)
                          :recentRuns (mapv schema/format-run runs)))))

(defn- create-workflow [body user-sub]
  (let [definition (-> (schema/body->definition body) schema/apply-defaults)
        errors (schema/validate-definition definition (other-names (list-definitions) nil))]
    (when (seq errors) (validation-error errors))
    (let [now (schema/now-iso)
          workflow-id (str (java.util.UUID/randomUUID))
          item (-> definition
                   (with-next-run (Instant/now))
                   (merge (schema/definition-key workflow-id)
                          {:workflow_id workflow-id
                           :run_count 0
                           :created now
                           :updated now
                           :created_by user-sub}))]
      (ddb/put-item ddb-table item)
      (println "Created workflow" (:name item) workflow-id)
      (r/created (schema/format-definition item)))))

(defn- deep-merge [a b]
  (if (and (map? a) (map? b))
    (merge-with deep-merge a b)
    b))

(defn- update-workflow [workflow-id body]
  (let [existing (load-definition workflow-id)
        changes (schema/body->definition body)
        _ (when (empty? changes) (validation-error ["No updatable fields in request body"]))
        ;; A new trigger replaces the old one wholesale so a stale schedule
        ;; cannot survive a type change; everything else merges by key.
        merged (-> (deep-merge (dissoc existing :trigger) (dissoc changes :trigger))
                   (assoc :trigger (or (:trigger changes) (:trigger existing)))
                   schema/apply-defaults)
        errors (schema/validate-definition merged (other-names (list-definitions) workflow-id))]
    (when (seq errors) (validation-error errors))
    (let [now (schema/now-iso)
          reschedule? (or (contains? changes :trigger) (contains? changes :enabled))
          item (-> (if reschedule? (with-next-run merged (Instant/now)) merged)
                   (assoc :updated now))]
      ;; Full put: the definition is one item and partial expressions would
      ;; need REMOVE handling for cleared nested fields.
      (ddb/put-item ddb-table item)
      (println "Updated workflow" (:name item) workflow-id)
      (r/ok-no-cache (schema/format-definition item)))))

(defn- delete-workflow [workflow-id]
  (load-definition workflow-id)
  (let [related (ddb/query-all ddb-table
                               :key-condition-expr "PK = :pk"
                               :expr-attr-values {":pk" (schema/run-pk workflow-id)})]
    (doseq [item related]
      (ddb/delete-item ddb-table {:PK (:PK item) :SK (:SK item)}))
    (ddb/delete-item ddb-table (schema/definition-key workflow-id))
    (println "Deleted workflow" workflow-id "and" (count related) "related items")
    (r/ok-no-cache {:deleted true :id workflow-id :relatedItemsDeleted (count related)})))

(defn- run-workflow [workflow-id body]
  (load-definition workflow-id)
  (when (str/blank? execute-fn)
    (throw (ex-info "WORKFLOW_EXECUTE_FUNCTION_NAME is not configured" {:type :config})))
  (let [document-path (:documentPath body)
        _ (when (and (some? document-path)
                     (or (not (string? document-path)) (str/blank? document-path)))
            (validation-error ["documentPath must be a non-empty string"]))
        run-id (str (java.util.UUID/randomUUID))]
    (lambda/invoke-async execute-fn
                         (cond-> {:workflow-id workflow-id
                                  :trigger "manual"
                                  :run-id run-id}
                           document-path (assoc :document-path document-path)))
    (println "Queued manual run" run-id "for workflow" workflow-id)
    (r/accepted {:runId run-id :workflowId workflow-id :status "queued"})))

(defn- list-runs [workflow-id params]
  (load-definition workflow-id)
  (let [limit (-> (r/parse-int-param params :limit default-runs-limit) (max 1) (min max-runs-limit))
        start-key (decode-cursor (or (get params :cursor) (get params "cursor")))
        [runs last-key] (query-runs workflow-id limit start-key)
        next-cursor (when (and last-key (= (count runs) limit))
                      (let [last-item (last runs)]
                        (encode-cursor {:PK (:PK last-item) :SK (:SK last-item)})))]
    (r/ok-no-cache (cond-> {:runs (mapv schema/format-run runs)
                            :count (count runs)}
                     next-cursor (assoc :nextCursor next-cursor)))))

;; =============================================================================
;; Routing
;; =============================================================================

(defn route-action
  "Resolve the action for a request from method, path parameter and path.
   Returns one of :list :create :get :update :delete :run :runs, or nil."
  [method workflow-id raw-path]
  (let [path (or raw-path "")
        sub (cond
              (str/ends-with? path "/run") :run
              (str/ends-with? path "/runs") :runs
              :else nil)]
    (cond
      (and (nil? workflow-id) (= method "GET")) :list
      (and (nil? workflow-id) (= method "POST")) :create
      (and workflow-id (= sub :run) (= method "POST")) :run
      (and workflow-id (= sub :runs) (= method "GET")) :runs
      (and workflow-id (nil? sub) (= method "GET")) :get
      (and workflow-id (nil? sub) (= method "PUT")) :update
      (and workflow-id (nil? sub) (= method "DELETE")) :delete
      :else nil)))

(def admin-actions #{:create :update :delete :run})

(defn handler
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          method (or (get-in event [:requestContext :http :method])
                     (get-in event ["requestContext" "http" "method"])
                     "GET")
          raw-path (or (:rawPath event) (get event "rawPath")
                       (get-in event [:requestContext :http :path]))
          path-params (r/parse-path-params event)
          workflow-id (or (:id path-params) (get path-params "id"))
          params (r/parse-query-params event)
          body (when-let [b (or (:body event) (get event "body"))]
                 (if (string? b) (json/parse-string b true) b))
          action (route-action method workflow-id raw-path)
          user-sub (r/get-user-sub event)]
      (println "Workflows API" method raw-path "action" action "user" user-sub)
      (cond
        (nil? action)
        (r/bad-request (str "Unsupported route: " method " " raw-path))

        (and (admin-actions action) (not (r/admin? event)))
        (r/forbidden "Admin access required")

        :else
        (case action
          :list (list-workflows)
          :create (create-workflow (or body {}) user-sub)
          :get (get-workflow workflow-id)
          :update (update-workflow workflow-id (or body {}))
          :delete (delete-workflow workflow-id)
          :run (run-workflow workflow-id (or body {}))
          :runs (list-runs workflow-id params))))

    (catch clojure.lang.ExceptionInfo e
      (let [data (ex-data e)]
        (case (:type data)
          :validation (r/bad-request (ex-message e))
          :not-found (r/not-found (ex-message e))
          (do (println "Error in workflows API:" (ex-message e))
              (.printStackTrace e)
              (r/internal-error "Failed to process workflow request")))))

    (catch Exception e
      (println "Error in workflows API:" (ex-message e))
      (.printStackTrace e)
      (r/internal-error "Failed to process workflow request"))))
