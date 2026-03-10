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

    /// Whether the user has viewed this search summary (computed server-side from viewed_at vs modified_at)
    var viewed: Bool = true

    var id: String {
        timestamp
    }

    init(
        timestamp: String,
        summary: String,
        topics: [String],
        noveltyScore: Double,
        significantUpdate: Bool,
        newItems: [String],
        changedItems: [String],
        removedItems: [String],
        analysis: String?,
        viewed: Bool = true
    ) {
        self.timestamp = timestamp
        self.summary = summary
        self.topics = topics
        self.noveltyScore = noveltyScore
        self.significantUpdate = significantUpdate
        self.newItems = newItems
        self.changedItems = changedItems
        self.removedItems = removedItems
        self.analysis = analysis
        self.viewed = viewed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        summary = try container.decode(String.self, forKey: .summary)
        topics = try container.decode([String].self, forKey: .topics)
        noveltyScore = try container.decode(Double.self, forKey: .noveltyScore)
        significantUpdate = try container.decode(Bool.self, forKey: .significantUpdate)
        newItems = try container.decode([String].self, forKey: .newItems)
        changedItems = try container.decode([String].self, forKey: .changedItems)
        removedItems = try container.decode([String].self, forKey: .removedItems)
        analysis = try container.decodeIfPresent(String.self, forKey: .analysis)
        viewed = try container.decodeIfPresent(Bool.self, forKey: .viewed) ?? true
    }
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
