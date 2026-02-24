import Foundation

/// Search mode for document queries
enum SearchMode: String, CaseIterable, Sendable {
    case keyword
    case semantic

    var displayName: String {
        switch self {
        case .keyword: "Keyword"
        case .semantic: "Semantic"
        }
    }
}

/// Protocol defining the API client interface for testability
protocol APIClientProtocol: Sendable {
    /// List documents with optional filtering and pagination
    /// - Parameters:
    ///   - classification: Optional classification to filter by
    ///   - limit: Maximum number of documents to return
    ///   - cursor: Pagination cursor from previous response
    ///   - sort: Sort order for results (modified or created)
    /// - Returns: Response containing documents and optional next cursor
    func listDocuments(
        classification: DocumentClassification?,
        limit: Int,
        cursor: String?,
        sort: DocumentSortOrder?
    ) async throws -> DocumentListResponse

    /// Get a single document by its key
    /// - Parameter key: The document's S3 key
    /// - Returns: The document with content loaded
    func getDocument(key: String) async throws -> Document

    /// Search documents by query
    /// - Parameters:
    ///   - query: Search query string
    ///   - limit: Maximum number of results
    ///   - mode: Search mode (keyword or semantic)
    /// - Returns: List of matching documents
    func search(query: String, limit: Int, mode: SearchMode) async throws -> [Document]

    /// List all tags in the vault
    /// - Returns: List of tags with document counts
    func listTags() async throws -> [Tag]

    /// List all classifications with counts
    /// - Returns: List of classifications with document counts
    func listClassifications() async throws -> [ClassificationCount]

    /// List daily summaries
    /// - Parameter limit: Maximum number of summaries to return
    /// - Returns: List of daily summaries
    func listSummaries(limit: Int) async throws -> [Summary]

    /// List weekly reports
    /// - Parameter limit: Maximum number of reports to return
    /// - Returns: List of weekly reports
    func listReports(limit: Int) async throws -> [Report]

    /// List documents with a specific tag
    /// - Parameters:
    ///   - tag: The tag to filter by
    ///   - limit: Maximum number of documents to return
    /// - Returns: List of documents with the specified tag
    func documentsByTag(tag: String, limit: Int) async throws -> [Document]

    /// Update a document's classification (manual override)
    /// - Parameters:
    ///   - documentId: The document's S3 key
    ///   - classification: The new classification to apply
    func updateClassification(documentId: String, classification: DocumentClassification) async throws

    /// Create a new document (admin only)
    /// - Parameters:
    ///   - key: The S3 key for the new document
    ///   - title: Optional title for the document
    ///   - content: The markdown content
    /// - Returns: The created document key and timestamp
    func createDocument(key: String, title: String?, content: String) async throws -> CreateDocumentResponse

    /// Update an existing document (admin only)
    /// - Parameters:
    ///   - key: The document's S3 key
    ///   - content: The new markdown content
    ///   - ifUnmodifiedSince: Optional conflict detection timestamp
    func updateDocument(key: String, content: String, ifUnmodifiedSince: String?) async throws

    /// Delete a document (admin only)
    /// - Parameter key: The document's S3 key
    func deleteDocument(key: String) async throws

    /// Get knowledge graph data (nodes and edges)
    /// - Returns: Graph data with nodes and edges for visualization
    func getGraphData() async throws -> GraphDataResponse

    // MARK: - Search Monitors

    /// List all search monitors
    func listSearchMonitors() async throws -> [SearchMonitor]

    /// Get a search monitor with recent summaries
    func getSearchMonitor(id: String) async throws -> SearchMonitorDetailResponse

    /// Create a new search monitor
    func createSearchMonitor(request: SearchMonitorRequest) async throws -> SearchMonitor

    /// Update an existing search monitor
    func updateSearchMonitor(id: String, request: SearchMonitorRequest) async throws -> SearchMonitor

    /// Delete a search monitor
    func deleteSearchMonitor(id: String) async throws

    /// List summaries for a search monitor
    func listSearchMonitorSummaries(monitorId: String, limit: Int) async throws -> [SearchSummary]

    /// Get a specific summary for a search monitor
    func getSearchMonitorSummary(monitorId: String, timestamp: String) async throws -> SearchSummary

    // MARK: - Device Tokens & Notifications

    /// Register a device for push notifications
    func registerDevice(request: DeviceRegistrationRequest) async throws -> DeviceRegistrationResponse

    /// Unregister a device from push notifications
    func unregisterDevice(deviceId: String) async throws

    /// List pending notifications for the current user
    func listNotifications() async throws -> NotificationListResponse

    /// Mark a notification as read
    func markNotificationRead(id: String) async throws
}

extension APIClientProtocol {
    func listDocuments(
        classification: DocumentClassification?,
        limit: Int,
        cursor: String?
    ) async throws -> DocumentListResponse {
        try await listDocuments(classification: classification, limit: limit, cursor: cursor, sort: nil)
    }

    func search(query: String, limit: Int) async throws -> [Document] {
        try await search(query: query, limit: limit, mode: .keyword)
    }
}
