(ns shared.secrets-manager-test
  "Tests for multi-secret caching in secrets_manager.clj"
  (:require [clojure.test :refer [deftest is testing use-fixtures]]
            [aws.secrets-manager :as sm]
            [com.grzm.awyeah.client.api :as aws]))

(use-fixtures :each
  (fn [f]
    (sm/clear-cache!)
    (f)))

(deftest get-secret-value-caches-by-key-test
  (testing "Different secret IDs are cached independently"
    (let [invoke-count (atom 0)]
      (with-redefs [aws/client (fn [_] :mock-client)
                    aws/invoke (fn [_ {:keys [request]}]
                                 (swap! invoke-count inc)
                                 {:SecretString (str "value-for-" (:SecretId request))})]
        ;; Fetch two different secrets
        (let [v1 (sm/get-secret-value "arn:aws:secretsmanager:us-east-1:123:secret:pkm-agent/brave-search-api-key")
              v2 (sm/get-secret-value "arn:aws:secretsmanager:us-east-1:123:secret:pkm-agent/apns-auth-key")]
          (is (= "value-for-arn:aws:secretsmanager:us-east-1:123:secret:pkm-agent/brave-search-api-key" v1))
          (is (= "value-for-arn:aws:secretsmanager:us-east-1:123:secret:pkm-agent/apns-auth-key" v2))
          (is (= 2 @invoke-count) "Should invoke AWS API once per distinct secret"))))))

(deftest get-secret-value-cache-hit-test
  (testing "Repeated calls for the same secret return cached value without API call"
    (let [invoke-count (atom 0)]
      (with-redefs [aws/client (fn [_] :mock-client)
                    aws/invoke (fn [_ _]
                                 (swap! invoke-count inc)
                                 {:SecretString "cached-secret"})]
        (let [v1 (sm/get-secret-value "pkm-agent/brave-search-api-key")
              v2 (sm/get-secret-value "pkm-agent/brave-search-api-key")
              v3 (sm/get-secret-value "pkm-agent/brave-search-api-key")]
          (is (= "cached-secret" v1))
          (is (= "cached-secret" v2))
          (is (= "cached-secret" v3))
          (is (= 1 @invoke-count) "Should only invoke AWS API once for repeated calls"))))))

(deftest get-secret-value-error-propagation-test
  (testing "AWS errors are propagated as exceptions"
    (with-redefs [aws/client (fn [_] :mock-client)
                  aws/invoke (fn [_ _]
                               {:cognitect.anomalies/category :cognitect.anomalies/not-found
                                :message "Secret not found"})]
      (is (thrown-with-msg? Exception #"SecretsManager GetSecretValue failed"
                            (sm/get-secret-value "pkm-agent/nonexistent"))))))

(deftest clear-cache-test
  (testing "clear-cache! forces fresh API calls on next access"
    (let [invoke-count (atom 0)]
      (with-redefs [aws/client (fn [_] :mock-client)
                    aws/invoke (fn [_ _]
                                 (swap! invoke-count inc)
                                 {:SecretString (str "value-" @invoke-count)})]
        (let [v1 (sm/get-secret-value "pkm-agent/test-key")]
          (is (= "value-1" v1))
          (sm/clear-cache!)
          (let [v2 (sm/get-secret-value "pkm-agent/test-key")]
            (is (= "value-2" v2))
            (is (= 2 @invoke-count) "Should re-fetch after cache clear")))))))
