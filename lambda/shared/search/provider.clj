(ns search.provider
  "Search provider abstraction for web search APIs")

(defprotocol SearchProvider
  "Protocol for web search providers"
  (search [this query opts]
    "Execute a web search query. Returns a vector of result maps with keys:
     :title, :url, :snippet, :date (optional)"))
