import Foundation

/// Status of a search monitor
enum SearchMonitorStatus: String, Codable, Sendable {
    case active
    case paused
}

/// A persistent search monitor that periodically executes web searches
struct SearchMonitor: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let searchTerms: [String]
    let intervalHours: Int
    let noveltyThreshold: Double
    let status: SearchMonitorStatus
    let lastExecuted: String?
    let nextExecution: String
    let created: String
    let modified: String
}

/// A summary produced by a search monitor execution
struct SearchSummary: Identifiable, Codable, Hashable, Sendable {
    let timestamp: String
    let summary: String
    let topics: [String]
    let noveltyScore: Double
    let significantUpdate: Bool
    let newItems: [String]
    let changedItems: [String]
    let removedItems: [String]
    let analysis: String?

    var id: String { timestamp }
}

// MARK: - API Response Wrappers

/// Response from GET /searches
struct SearchMonitorListResponse: Codable, Sendable {
    let monitors: [SearchMonitor]
    let count: Int
}

/// Response from GET /searches/{id}
struct SearchMonitorDetailResponse: Codable, Sendable {
    let monitor: SearchMonitor
    let summaries: [SearchSummary]
    let summaryCount: Int
}

/// Response from GET /searches/{id}/summaries
struct SearchSummaryListResponse: Codable, Sendable {
    let summaries: [SearchSummary]
    let count: Int
    let monitorId: String
}

/// Request body for creating/updating a search monitor
struct SearchMonitorRequest: Codable, Sendable {
    var name: String?
    var description: String?
    var searchTerms: [String]?
    var intervalHours: Int?
    var noveltyThreshold: Double?
    var status: SearchMonitorStatus?
}
