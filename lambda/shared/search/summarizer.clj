(ns search.summarizer
  "Summarization and comparison logic for persistent search results.
   Uses Bedrock Sonnet to synthesize search results into summaries
   and compute novelty scores by comparing against previous summaries."
  (:require [aws.bedrock :as bedrock]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ^:private summarize-system-prompt
  "You are a research analyst for a Personal Knowledge Management system.

Your task is to synthesize web search results into a coherent summary organized by topic/theme.

Respond with a JSON object containing:
- \"summary\": A structured markdown summary of the search results, organized by themes or topics. Include key findings, notable sources, and relevant dates.
- \"topics\": An array of 1-5 main topic labels extracted from the results.

Return ONLY valid JSON, no additional text.")

(def ^:private compare-system-prompt
  "You are a research analyst for a Personal Knowledge Management system.

Your task is to compare a new search summary against a previous summary and assess how much genuinely new information is present.

Respond with a JSON object containing:
- \"novelty_score\": A number from 0.0 to 1.0 where 0.0 means no new information and 1.0 means entirely new information
- \"new_items\": An array of strings describing genuinely new findings
- \"changed_items\": An array of strings describing information that has changed or been updated
- \"removed_items\": An array of strings describing information that no longer appears
- \"analysis\": A brief (1-2 sentence) explanation of the novelty assessment

Return ONLY valid JSON, no additional text.")

(defn- format-search-results-for-prompt
  "Format search result snapshots into a readable text block for the LLM"
  [search-results]
  (str/join "\n\n"
            (map (fn [{:keys [term results]}]
                   (str "## Search: " term "\n\n"
                        (if (empty? results)
                          "(No results)"
                          (str/join "\n"
                                    (map-indexed
                                     (fn [i {:keys [title url snippet date]}]
                                       (str (inc i) ". **" title "**\n"
                                            "   URL: " url "\n"
                                            "   " snippet
                                            (when date (str "\n   Date: " date))))
                                     results)))))
                 search-results)))

(defn- strip-markdown-fences
  "Strip markdown code fences from LLM response text"
  [text]
  (-> text
      str/trim
      (str/replace #"^```[a-z]*\s*\n?" "")
      (str/replace #"\n?\s*```$" "")
      str/trim))

(defn summarize-results
  "Generate a summary from search results using Bedrock.
   Returns {:summary string :topics [string]}"
  [model-id search-results]
  (let [formatted (format-search-results-for-prompt search-results)
        prompt (str "Summarize the following web search results:\n\n" formatted)
        response (bedrock/invoke-model model-id prompt
                                       {:max-tokens 4000
                                        :temperature 0.3
                                        :system summarize-system-prompt})
        text (bedrock/extract-text response)]
    (try
      (json/parse-string (strip-markdown-fences text) true)
      (catch Exception e
        (println "Error parsing summary response:" (ex-message e) "raw:" text)
        {:summary text :topics []}))))

(defn compare-summaries
  "Compare a new summary against a previous summary using Bedrock.
   Returns {:novelty_score number :new_items [...] :changed_items [...] :removed_items [...] :analysis string}"
  [model-id new-summary previous-summary]
  (if (nil? previous-summary)
    ;; First summary for this monitor — everything is new
    {:novelty_score 1.0
     :new_items ["First search execution - all results are new"]
     :changed_items []
     :removed_items []
     :analysis "This is the first search execution for this monitor, so all information is new."}

    (let [prompt (str "Compare these two search summaries and assess novelty.\n\n"
                      "## Previous Summary\n" previous-summary
                      "\n\n## New Summary\n" new-summary)
          response (bedrock/invoke-model model-id prompt
                                         {:max-tokens 2000
                                          :temperature 0.2
                                          :system compare-system-prompt})
          text (bedrock/extract-text response)]
      (try
        (let [parsed (json/parse-string (strip-markdown-fences text) true)]
          (update parsed :novelty_score #(double (or % 0.0))))
        (catch Exception e
          (println "Error parsing comparison response:" (ex-message e) "raw:" text)
          {:novelty_score 0.0
           :new_items []
           :changed_items []
           :removed_items []
           :analysis "Failed to parse comparison"})))))

(defn format-search-report
  "Format a search summary report as markdown for S3 output"
  [monitor-name summary-text topics diff timestamp]
  (let [{:keys [novelty_score new_items changed_items removed_items analysis]} diff]
    (str "---\n"
         "monitor: " monitor-name "\n"
         "date: " timestamp "\n"
         "novelty_score: " novelty_score "\n"
         "topics: [" (str/join ", " topics) "]\n"
         "---\n\n"
         "# Search Monitor: " monitor-name "\n\n"
         "**Date:** " timestamp "\n"
         "**Novelty Score:** " (format "%.2f" novelty_score) "\n\n"
         "## Summary\n\n"
         summary-text "\n\n"
         "## What's New\n\n"
         (if (seq analysis)
           (str analysis "\n\n")
           "")
         (when (seq new_items)
           (str "### New Findings\n"
                (str/join "\n" (map #(str "- " %) new_items)) "\n\n"))
         (when (seq changed_items)
           (str "### Changes\n"
                (str/join "\n" (map #(str "- " %) changed_items)) "\n\n"))
         (when (seq removed_items)
           (str "### No Longer Appearing\n"
                (str/join "\n" (map #(str "- " %) removed_items)) "\n")))))
