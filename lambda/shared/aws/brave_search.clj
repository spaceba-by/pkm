(ns aws.brave-search
  "Brave Search API client implementing SearchProvider protocol"
  (:require [babashka.http-client :as http]
            [cheshire.core :as json]
            [search.provider :as sp]))

(defn- parse-results
  "Parse Brave Search API response into normalized result maps"
  [response-body]
  (let [parsed (json/parse-string response-body true)
        web-results (get-in parsed [:web :results] [])]
    (mapv (fn [r]
            (cond-> {:title (or (:title r) "")
                     :url (or (:url r) "")
                     :snippet (or (:description r) "")}
              (:page_age r) (assoc :date (:page_age r))))
          (take 10 web-results))))

(defn- do-search
  "Execute a Brave Search API request"
  [api-key query {:keys [count] :or {count 10}}]
  (let [response (http/get "https://api.search.brave.com/res/v1/web/search"
                           {:query-params {"q" query
                                           "count" (str count)}
                            :headers {"Accept" "application/json"
                                      "Accept-Encoding" "gzip"
                                      "X-Subscription-Token" api-key}
                            :throw false})]
    (if (= 200 (:status response))
      (parse-results (:body response))
      (throw (ex-info "Brave Search API request failed"
                      {:status (:status response)
                       :body (:body response)
                       :query query})))))

(defrecord BraveSearchProvider [api-key]
  sp/SearchProvider
  (search [_ query opts]
    (do-search api-key query opts)))

(defn create-provider
  "Create a BraveSearchProvider with the given API key"
  [api-key]
  (->BraveSearchProvider api-key))
