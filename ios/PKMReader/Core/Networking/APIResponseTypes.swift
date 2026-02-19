// swiftlint:disable:this file_name
import Foundation

// MARK: - API Response Types

struct SearchResponse: Codable, Sendable {
    let query: String
    let results: [Document]
    let count: Int
}

struct TagListResponse: Codable, Sendable {
    let tags: [Tag]
    let count: Int
}

struct ClassificationListResponse: Codable, Sendable {
    let classifications: [ClassificationCount]
}

struct SummaryListResponse: Codable, Sendable {
    let summaries: [Summary]
    let count: Int
}

struct ReportListResponse: Codable, Sendable {
    let reports: [Report]
    let count: Int
}

struct DocumentsByTagResponse: Codable, Sendable {
    let tag: String
    let documents: [Document]
    let count: Int
}

struct CreateDocumentResponse: Codable, Sendable {
    let key: String
    let title: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case key
        case title
        case createdAt = "created_at"
    }
}
