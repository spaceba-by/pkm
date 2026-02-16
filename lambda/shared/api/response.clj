(ns api.response
  "Utilities for API Gateway Lambda responses"
  (:require [cheshire.core :as json]
            [clojure.string :as str]))

(defn ok
  "Create a 200 OK response with caching"
  [body]
  {:statusCode 200
   :headers {"Content-Type" "application/json"
             "Cache-Control" "private, max-age=60"}
   :body (json/generate-string body)})

(defn ok-no-cache
  "Create a 200 OK response with no caching"
  [body]
  {:statusCode 200
   :headers {"Content-Type" "application/json"
             "Cache-Control" "no-cache, no-store, must-revalidate"}
   :body (json/generate-string body)})

(defn bad-request
  "Create a 400 Bad Request response"
  [message]
  {:statusCode 400
   :headers {"Content-Type" "application/json"}
   :body (json/generate-string {:error "Bad Request"
                                :message message})})

(defn not-found
  "Create a 404 Not Found response"
  [message]
  {:statusCode 404
   :headers {"Content-Type" "application/json"}
   :body (json/generate-string {:error "Not Found"
                                :message message})})

(defn internal-error
  "Create a 500 Internal Server Error response"
  [message]
  {:statusCode 500
   :headers {"Content-Type" "application/json"}
   :body (json/generate-string {:error "Internal Server Error"
                                :message message})})

(defn parse-query-params
  "Parse query parameters from API Gateway event"
  [event]
  (or (get event :queryStringParameters)
      (get event "queryStringParameters")
      {}))

(defn parse-path-params
  "Parse path parameters from API Gateway event"
  [event]
  (or (get event :pathParameters)
      (get event "pathParameters")
      {}))

(defn parse-int-param
  "Parse integer parameter with default"
  [params key default-val]
  (if-let [val (or (get params key)
                   (get params (name key)))]
    (try (Integer/parseInt (str val))
         (catch NumberFormatException _ default-val))
    default-val))

(defn truncate-timestamp
  "Truncate ISO 8601 timestamp to second precision for iOS compatibility.
   Handles numeric (epoch) timestamps by converting to ISO 8601 string."
  [ts]
  (cond
    (nil? ts) nil
    (number? ts) (let [epoch-secs (if (> (long ts) 10000000000)
                                    (quot (long ts) 1000)
                                    (long ts))
                       instant (java.time.Instant/ofEpochSecond epoch-secs)]
                   (str instant))
    (string? ts) (if (re-find #"\.\d+" ts)
                   (str/replace ts #"\.\d+(Z|[+-].*)$" "$1")
                   ts)
    :else nil))

(defn get-user-sub
  "Extract user sub (Cognito user ID) from JWT claims in API Gateway v2 format"
  [event]
  (or
   ;; API Gateway HTTP API v2 format
   (get-in event [:requestContext :authorizer :jwt :claims :sub])
   (get-in event ["requestContext" "authorizer" "jwt" "claims" "sub"])
   ;; Fallback
   "unknown"))
