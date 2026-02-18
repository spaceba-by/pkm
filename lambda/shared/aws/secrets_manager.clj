(ns aws.secrets-manager
  "Secrets Manager utilities using awyeah client"
  (:require [com.grzm.awyeah.client.api :as aws]))

(defonce ^:private sm-client
  (delay (aws/client {:api :secretsmanager})))

(defn- check-error
  "Check AWS response for errors and throw if found"
  [response operation]
  (when-let [error-category (:cognitect.anomalies/category response)]
    (throw (ex-info (str "SecretsManager " operation " failed: "
                         (or (:message response) error-category))
                    {:operation operation
                     :error-category error-category
                     :error-code (:cognitect.aws.error/code response)
                     :response response})))
  response)

(defonce ^:private secret-cache (atom {}))

(defn get-secret-value
  "Retrieves a secret value by ARN or name. Caches the result in-memory
   for the lifetime of the Lambda container."
  [secret-id]
  (if-let [cached (get @secret-cache secret-id)]
    cached
    (let [response (-> (aws/invoke @sm-client
                                   {:op :GetSecretValue
                                    :request {:SecretId secret-id}})
                       (check-error "GetSecretValue"))
          value (:SecretString response)]
      (swap! secret-cache assoc secret-id value)
      value)))
