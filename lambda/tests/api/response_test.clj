(ns api.response-test
  "Tests for API response utilities"
  (:require [clojure.test :refer [deftest is testing]]
            [api.response :as r]
            [cheshire.core :as json]))

(deftest ok-test
  (testing "Creates 200 response with body"
    (let [response (r/ok {:message "success"})]
      (is (= 200 (:statusCode response)))
      (is (= "application/json" (get-in response [:headers "Content-Type"])))
      (is (= "private, max-age=60" (get-in response [:headers "Cache-Control"])))
      (let [body (json/parse-string (:body response) true)]
        (is (= "success" (:message body))))))

  (testing "Handles nested data structures"
    (let [response (r/ok {:items [{:id 1} {:id 2}] :count 2})]
      (is (= 200 (:statusCode response)))
      (let [body (json/parse-string (:body response) true)]
        (is (= 2 (count (:items body))))
        (is (= 2 (:count body)))))))

(deftest ok-no-cache-test
  (testing "Creates 200 response without caching"
    (let [response (r/ok-no-cache {:data "fresh"})]
      (is (= 200 (:statusCode response)))
      (is (= "no-cache, no-store, must-revalidate"
             (get-in response [:headers "Cache-Control"]))))))

(deftest bad-request-test
  (testing "Creates 400 response with error message"
    (let [response (r/bad-request "Invalid input")]
      (is (= 400 (:statusCode response)))
      (let [body (json/parse-string (:body response) true)]
        (is (= "Bad Request" (:error body)))
        (is (= "Invalid input" (:message body)))))))

(deftest not-found-test
  (testing "Creates 404 response with error message"
    (let [response (r/not-found "Document not found")]
      (is (= 404 (:statusCode response)))
      (let [body (json/parse-string (:body response) true)]
        (is (= "Not Found" (:error body)))
        (is (= "Document not found" (:message body)))))))

(deftest internal-error-test
  (testing "Creates 500 response with error message"
    (let [response (r/internal-error "Something went wrong")]
      (is (= 500 (:statusCode response)))
      (let [body (json/parse-string (:body response) true)]
        (is (= "Internal Server Error" (:error body)))
        (is (= "Something went wrong" (:message body)))))))

(deftest parse-query-params-test
  (testing "Extracts query params with keyword keys"
    (let [event {:queryStringParameters {:q "search" :limit "10"}}
          params (r/parse-query-params event)]
      (is (= "search" (:q params)))
      (is (= "10" (:limit params)))))

  (testing "Extracts query params with string keys"
    (let [event {"queryStringParameters" {"q" "test" "page" "2"}}
          params (r/parse-query-params event)]
      (is (= "test" (get params "q")))
      (is (= "2" (get params "page")))))

  (testing "Returns empty map when no params"
    (let [params (r/parse-query-params {})]
      (is (= {} params)))))

(deftest parse-path-params-test
  (testing "Extracts path params with keyword keys"
    (let [event {:pathParameters {:id "123" :key "docs/note.md"}}
          params (r/parse-path-params event)]
      (is (= "123" (:id params)))
      (is (= "docs/note.md" (:key params)))))

  (testing "Extracts path params with string keys"
    (let [event {"pathParameters" {"tag" "clojure"}}
          params (r/parse-path-params event)]
      (is (= "clojure" (get params "tag")))))

  (testing "Returns empty map when no path params"
    (let [params (r/parse-path-params {})]
      (is (= {} params)))))

(deftest parse-int-param-test
  (testing "Parses integer from string"
    (let [params {:limit "25"}]
      (is (= 25 (r/parse-int-param params :limit 10)))))

  (testing "Returns default for missing param"
    (let [params {}]
      (is (= 50 (r/parse-int-param params :limit 50)))))

  (testing "Returns default for invalid integer"
    (let [params {:limit "not-a-number"}]
      (is (= 20 (r/parse-int-param params :limit 20)))))

  (testing "Works with string keys"
    (let [params {"page" "3"}]
      (is (= 3 (r/parse-int-param params "page" 1))))))

(deftest truncate-timestamp-test
  (testing "Strips fractional seconds with Z suffix"
    (is (= "2026-02-15T21:27:58Z"
           (r/truncate-timestamp "2026-02-15T21:27:58.923258Z"))))

  (testing "Strips fractional seconds with positive offset"
    (is (= "2026-02-15T21:27:58+05:30"
           (r/truncate-timestamp "2026-02-15T21:27:58.123+05:30"))))

  (testing "Strips fractional seconds with negative offset"
    (is (= "2026-02-15T21:27:58-04:00"
           (r/truncate-timestamp "2026-02-15T21:27:58.999999-04:00"))))

  (testing "Passes through timestamps without fractional seconds"
    (is (= "2026-02-15T21:27:58Z"
           (r/truncate-timestamp "2026-02-15T21:27:58Z"))))

  (testing "Passes through nil"
    (is (nil? (r/truncate-timestamp nil))))

  (testing "Passes through default timestamp"
    (is (= "1970-01-01T00:00:00Z"
           (r/truncate-timestamp "1970-01-01T00:00:00Z"))))

  (testing "Converts numeric epoch timestamp (seconds) to ISO string"
    (is (= "1970-01-01T00:00:00Z"
           (r/truncate-timestamp 0)))
    (is (= "2024-02-15T00:00:00Z"
           (r/truncate-timestamp 1707955200))))

  (testing "Converts millisecond epoch timestamp to ISO string"
    (is (= "2024-02-15T00:00:00Z"
           (r/truncate-timestamp 1707955200000))))

  (testing "Handles floating-point epoch seconds by truncating fractional part"
    (is (= "2024-02-15T00:00:00Z"
           (r/truncate-timestamp 1707955200.9))))

  (testing "Handles negative epoch timestamps before 1970-01-01"
    (is (= "1969-12-31T23:59:59Z"
           (r/truncate-timestamp -1))))

  (testing "Returns nil for non-string non-numeric values"
    (is (nil? (r/truncate-timestamp true)))))

(deftest get-user-sub-test
  (testing "Extracts user sub from JWT claims (keyword keys)"
    (let [event {:requestContext {:authorizer {:jwt {:claims {:sub "user-123"}}}}}]
      (is (= "user-123" (r/get-user-sub event)))))

  (testing "Extracts user sub from JWT claims (string keys)"
    (let [event {"requestContext" {"authorizer" {"jwt" {"claims" {"sub" "user-456"}}}}}]
      (is (= "user-456" (r/get-user-sub event)))))

  (testing "Returns 'unknown' when no user sub"
    (let [event {}]
      (is (= "unknown" (r/get-user-sub event))))))
