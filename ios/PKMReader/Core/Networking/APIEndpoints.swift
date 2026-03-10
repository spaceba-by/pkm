import Foundation

/// API endpoint definitions
enum APIEndpoints {
    /// List documents endpoint
    static func documents(
        classification: DocumentClassification? = nil,
        limit: Int = 50,
        cursor: String? = nil
    ) -> String {
        var path = "/documents"
        var queryItems: [String] = []

        queryItems.append("limit=\(limit)")

        if let classification {
            queryItems.append("classification=\(classification.rawValue)")
        }

        if let cursor {
            let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
            queryItems.append("cursor=\(encoded)")
        }

        if !queryItems.isEmpty {
            path += "?" + queryItems.joined(separator: "&")
        }

        return path
    }

    /// Single document endpoint
    static func document(key: String) -> String {
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        return "/documents/\(encodedKey)"
    }

    /// Search endpoint
    static func search(query: String, limit: Int = 20) -> String {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return "/search?q=\(encodedQuery)&limit=\(limit)"
    }

    /// Tags endpoint
    static let tags = "/tags"

    /// Documents by tag endpoint
    static func documentsByTag(tag: String) -> String {
        let encodedTag = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag
        return "/tags/\(encodedTag)/documents"
    }

    /// Daily summaries endpoint
    static let summaries = "/summaries"

    /// Weekly reports endpoint
    static let reports = "/reports"

    /// Knowledge graph data endpoint
    static let graph = "/graph"

    /// Search monitors endpoint
    static let searchMonitors = "/searches"

    /// Single search monitor endpoint
    static func searchMonitor(id: String) -> String {
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return "/searches/\(encodedId)"
    }

    /// Search monitor summaries endpoint
    static func searchMonitorSummaries(monitorId: String, limit: Int = 20) -> String {
        let encodedId = monitorId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? monitorId
        return "/searches/\(encodedId)/summaries?limit=\(limit)"
    }

    /// Single search monitor summary endpoint
    static func searchMonitorSummary(monitorId: String, timestamp: String) -> String {
        let encodedId = monitorId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? monitorId
        let encodedTs = timestamp.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? timestamp
        return "/searches/\(encodedId)/summaries/\(encodedTs)"
    }

    // MARK: - Insight Viewed Status

    /// Mark a daily summary as viewed
    static func markSummaryViewed(date: String) -> String {
        "/summaries/\(date)/viewed"
    }

    /// Mark a weekly report as viewed
    static func markReportViewed(week: String) -> String {
        "/reports/\(week)/viewed"
    }

    /// Mark a search summary as viewed
    static func markSearchSummaryViewed(monitorId: String, timestamp: String) -> String {
        let encodedId = monitorId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? monitorId
        let encodedTs = timestamp.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? timestamp
        return "/searches/\(encodedId)/summaries/\(encodedTs)/viewed"
    }

    /// Mark all insights as viewed
    static let markAllViewed = "/insights/mark-all-viewed"

    /// Get unviewed insight count
    static let unviewedCount = "/insights/unviewed-count"
}
