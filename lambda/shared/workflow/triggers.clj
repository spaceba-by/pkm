(ns workflow.triggers
  "Trigger and filter matching for custom agent workflows.

   Pure functions over workflow definitions as stored in DynamoDB (snake_case
   attributes) and document METADATA records. Dispatch Lambdas call these to
   decide which workflows an event fires; nothing here touches AWS."
  (:require [clojure.string :as str])
  (:import [java.time DayOfWeek Duration Instant ZoneOffset]
           [java.time.temporal ChronoUnit TemporalAdjusters]))

;; =============================================================================
;; Constants
;; =============================================================================

(def trigger-types #{"document" "schedule" "manual" "command"})
(def frequencies #{"hourly" "daily" "weekly"})

(def default-cooldown-minutes 60)
(def default-lookback-days 7)
(def max-set-documents
  "Upper bound on documents selected for schedule and manual set runs"
  50)

(def day-of-week
  {"monday" DayOfWeek/MONDAY
   "tuesday" DayOfWeek/TUESDAY
   "wednesday" DayOfWeek/WEDNESDAY
   "thursday" DayOfWeek/THURSDAY
   "friday" DayOfWeek/FRIDAY
   "saturday" DayOfWeek/SATURDAY
   "sunday" DayOfWeek/SUNDAY})

(defn- iso
  "Instant as ISO 8601 at second precision"
  [^Instant instant]
  (str (.truncatedTo instant ChronoUnit/SECONDS)))

;; =============================================================================
;; Filters
;; =============================================================================

(defn normalize-tag
  "Lower-case a tag and strip a leading #"
  [tag]
  (-> tag str str/trim (str/replace #"^#" "") str/lower-case))

(defn matches-filter?
  "True when a document METADATA record satisfies a workflow filter. Every
   present condition must hold; an absent or empty condition matches all.
     :path_prefix     - document path starts with the prefix (case-sensitive)
     :tags            - document has at least one listed tag (case-insensitive)
     :classifications - document classification is one of the listed values
   :lookback_days is a set-selection window and is not evaluated here."
  [{:keys [path_prefix tags classifications]} doc]
  (let [path (or (:document_path doc) (:path doc) "")
        doc-tags (set (map normalize-tag (or (:tags doc) [])))
        wanted-tags (set (map normalize-tag (or tags [])))]
    (and (or (str/blank? path_prefix)
             (str/starts-with? path path_prefix))
         (or (empty? wanted-tags)
             (boolean (some wanted-tags doc-tags)))
         (or (empty? classifications)
             (contains? (set classifications) (:classification doc))))))

(defn- doc-modified
  [doc]
  (or (:modified doc) ""))

(defn select-documents
  "Choose the document set for a schedule or manual run: records passing the
   filter, newest `modified` first, capped at max-set-documents. The caller
   supplies candidates already restricted to the lookback window."
  [wf-filter docs]
  (->> docs
       (filter #(matches-filter? wf-filter %))
       (sort-by doc-modified #(compare %2 %1))
       (take max-set-documents)
       vec))

(defn lookback-since
  "ISO timestamp for the start of a filter's lookback window ending at now"
  [wf-filter ^Instant now]
  (let [days (or (:lookback_days wf-filter) default-lookback-days)]
    (iso (.minus now (Duration/ofDays days)))))

;; =============================================================================
;; Workflow matching
;; =============================================================================

(defn enabled?
  "A workflow runs only when explicitly enabled"
  [workflow]
  (true? (:enabled workflow)))

(defn trigger-type
  [workflow]
  (get-in workflow [:trigger :type]))

(defn document-workflows
  "Enabled document-triggered workflows whose filter matches the document"
  [workflows doc]
  (->> workflows
       (filter enabled?)
       (filter #(= "document" (trigger-type %)))
       (filter #(matches-filter? (:filter %) doc))
       vec))

(defn find-command-workflow
  "The enabled command-triggered workflow addressed by @workflow:<name>, or nil"
  [workflows command-name]
  (let [wanted (some-> command-name str/trim str/lower-case)]
    (when-not (str/blank? wanted)
      (->> workflows
           (filter enabled?)
           (filter #(= "command" (trigger-type %)))
           (filter #(= wanted (:name %)))
           first))))

(defn due?
  "True when a schedule-triggered workflow should run at `now`. A missing
   next_run counts as due so a definition that never had one computed
   self-heals on the next poll."
  [workflow ^Instant now]
  (and (enabled? workflow)
       (= "schedule" (trigger-type workflow))
       (let [next-run (:next_run workflow)]
         (or (str/blank? next-run)
             (not (pos? (compare next-run (iso now))))))))

(defn due-workflows
  "Enabled schedule-triggered workflows whose next_run has passed"
  [workflows ^Instant now]
  (vec (filter #(due? % now) workflows)))

;; =============================================================================
;; Schedules
;; =============================================================================

(defn validate-schedule
  "Validate a schedule map. Returns a vector of error messages; empty when valid."
  [{:keys [frequency minute hour day_of_week] :as schedule}]
  (cond
    (nil? schedule) ["Schedule is required for schedule-triggered workflows"]
    (not (frequencies frequency)) [(str "Schedule frequency must be one of: " (str/join ", " (sort frequencies)))]
    :else
    (cond-> []
      (and (some? minute) (not (and (integer? minute) (<= 0 minute 59))))
      (conj "Schedule minute must be an integer from 0 to 59")

      (and (#{"daily" "weekly"} frequency)
           (not (and (integer? hour) (<= 0 hour 23))))
      (conj "Schedule hour must be an integer from 0 to 23")

      (and (= "weekly" frequency)
           (not (contains? day-of-week (some-> day_of_week str/lower-case))))
      (conj (str "Schedule day_of_week must be one of: " (str/join ", " (keys day-of-week)))))))

(defn next-run
  "ISO timestamp of the first scheduled occurrence strictly after `now`, in
   UTC. Missing fields default to minute 0, hour 0 and monday."
  [{:keys [frequency minute hour day_of_week]} ^Instant now]
  (let [minute (or minute 0)
        hour (or hour 0)
        day (get day-of-week (some-> day_of_week str/lower-case) DayOfWeek/MONDAY)
        now-utc (.atZone now ZoneOffset/UTC)
        at-time (fn [zdt] (-> zdt
                              (.withHour hour)
                              (.withMinute minute)
                              (.withSecond 0)
                              (.withNano 0)))
        candidate (case frequency
                    "hourly" (-> now-utc (.withMinute minute) (.withSecond 0) (.withNano 0))
                    "daily" (at-time now-utc)
                    "weekly" (at-time (.with now-utc (TemporalAdjusters/nextOrSame day)))
                    (throw (ex-info (str "Unknown schedule frequency: " frequency)
                                    {:type :validation :frequency frequency})))
        step (case frequency
               "hourly" (Duration/ofHours 1)
               "daily" (Duration/ofDays 1)
               "weekly" (Duration/ofDays 7))
        candidate (if (.isAfter (.toInstant candidate) now)
                    candidate
                    (.plus candidate step))]
    (iso (.toInstant candidate))))

;; =============================================================================
;; Cooldown
;; =============================================================================

(defn in-cooldown?
  "True when a (workflow, document) pair last ran less than cooldown-minutes
   before `now`. A nil last run or a non-positive cooldown never blocks."
  [last-run-iso cooldown-minutes ^Instant now]
  (let [cooldown (or cooldown-minutes default-cooldown-minutes)]
    (boolean
     (and (not (str/blank? last-run-iso))
          (pos? cooldown)
          (.isBefore now (.plus (Instant/parse last-run-iso)
                                (Duration/ofMinutes cooldown)))))))
