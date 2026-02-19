(ns persistent-search.execute-test
  "Unit tests for persistent search execute Lambda.

   Note: Functions are duplicated here rather than imported from handler
   namespaces because all Lambda handlers use the same 'handler' namespace
   name (required by the Lambda runtime)."
  (:require [clojure.test :refer [deftest is testing]]
            [search.provider :as sp])
  (:import [java.time Instant Duration]
           [java.time.temporal ChronoUnit]))

;; =============================================================================
;; Duplicated pure functions from handler for testing
;; =============================================================================

(defn- now-iso []
  (str (.truncatedTo (Instant/now) ChronoUnit/SECONDS)))

(defn- compute-next-execution [interval-hours]
  (let [next-time (.plus (Instant/now) (Duration/ofHours interval-hours))]
    (str (.truncatedTo next-time ChronoUnit/SECONDS))))

;; =============================================================================
;; Mock search provider for testing
;; =============================================================================

(defrecord MockSearchProvider [results-fn]
  sp/SearchProvider
  (search [_ query opts]
    (results-fn query opts)))

(defn mock-provider
  "Create a mock search provider that returns canned results"
  [results-map]
  (->MockSearchProvider
   (fn [query _]
     (get results-map query
          [{:title "Default Result"
            :url "https://example.com"
            :snippet "Default snippet"}]))))

;; Duplicated from handler for testing
(defn execute-search-terms [provider terms]
  (mapv (fn [term]
          {:term term
           :results (try
                      (sp/search provider term {})
                      (catch Exception e
                        (println "Search failed for term:" term "-" (ex-message e))
                        []))})
        terms))

;; =============================================================================
;; Tests
;; =============================================================================

(deftest compute-next-execution-test
  (testing "Computes a future timestamp"
    (let [now (Instant/now)
          result (compute-next-execution 6)
          result-instant (Instant/parse result)]
      (is (some? result))
      (is (.isAfter result-instant now))
      ;; Should be approximately 6 hours from now (within 5 seconds tolerance)
      (let [expected (.plus now (Duration/ofHours 6))
            diff (Math/abs (.getSeconds (Duration/between result-instant expected)))]
        (is (< diff 5) "Should be within 5 seconds of expected time"))))

  (testing "Different interval values"
    (let [one-hour (Instant/parse (compute-next-execution 1))
          twenty-four (Instant/parse (compute-next-execution 24))]
      (is (.isBefore one-hour twenty-four)
          "1-hour interval should be before 24-hour interval"))))

(deftest execute-search-terms-test
  (testing "Executes searches for all terms"
    (let [provider (mock-provider
                    {"clojure" [{:title "Clojure.org" :url "https://clojure.org" :snippet "Clojure lang"}]
                     "babashka" [{:title "Babashka" :url "https://babashka.org" :snippet "Fast Clojure"}]})
          results (execute-search-terms provider ["clojure" "babashka"])]
      (is (= 2 (count results)))
      (is (= "clojure" (:term (first results))))
      (is (= "babashka" (:term (second results))))
      (is (= 1 (count (:results (first results)))))
      (is (= "Clojure.org" (:title (first (:results (first results))))))))

  (testing "Returns empty results on error"
    (let [error-provider (->MockSearchProvider
                          (fn [_ _] (throw (ex-info "API error" {}))))
          results (execute-search-terms error-provider ["test"])]
      (is (= 1 (count results)))
      (is (= "test" (:term (first results))))
      (is (empty? (:results (first results))))))

  (testing "Handles empty terms list"
    (let [provider (mock-provider {})
          results (execute-search-terms provider [])]
      (is (empty? results)))))

(deftest mock-provider-test
  (testing "Mock provider returns configured results"
    (let [provider (mock-provider
                    {"test" [{:title "Test" :url "https://test.com" :snippet "A test"}]})
          results (sp/search provider "test" {})]
      (is (= 1 (count results)))
      (is (= "Test" (:title (first results))))))

  (testing "Mock provider returns default for unknown queries"
    (let [provider (mock-provider {})
          results (sp/search provider "unknown" {})]
      (is (= 1 (count results)))
      (is (= "Default Result" (:title (first results)))))))
