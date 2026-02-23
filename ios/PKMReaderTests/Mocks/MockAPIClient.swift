import Foundation
@testable import PKMReader

/// Mock API client for unit testing
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    // MARK: - Configurable Results

    /// Result to return from listDocuments
    var listDocumentsResult: Result<DocumentListResponse, Error> = .success(
        DocumentListResponse(documents: [], nextCursor: nil)
    )

    /// Result to return from getDocument
    var getDocumentResult: Result<Document, Error>?

    /// Result to return from search
    var searchResult: Result<[Document], Error> = .success([])

    /// Result to return from listTags
    var listTagsResult: Result<[Tag], Error> = .success([])

    /// Result to return from listClassifications
    var listClassificationsResult: Result<[ClassificationCount], Error> = .success([])

    /// Result to return from listSummaries
    var listSummariesResult: Result<[Summary], Error> = .success([])

    /// Result to return from listReports
    var listReportsResult: Result<[Report], Error> = .success([])

    /// Result to return from documentsByTag
    var documentsByTagResult: Result<[Document], Error> = .success([])

    /// Result to return from updateClassification
    var updateClassificationResult: Result<Void, Error> = .success(())

    /// Result to return from createDocument
    var createDocumentResult: Result<CreateDocumentResponse, Error> = .success(
        CreateDocumentResponse(key: "test.md", title: "Test", createdAt: "2024-01-01T00:00:00Z")
    )

    /// Result to return from updateDocument
    var updateDocumentResult: Result<Void, Error> = .success(())

    /// Result to return from deleteDocument
    var deleteDocumentResult: Result<Void, Error> = .success(())

    /// Result to return from getGraphData
    var getGraphDataResult: Result<GraphDataResponse, Error> = .success(
        GraphDataResponse(nodes: [], edges: [], nodeCount: 0, edgeCount: 0)
    )

    /// Result to return from listSearchMonitors
    var listSearchMonitorsResult: Result<[SearchMonitor], Error> = .success([])

    /// Result to return from getSearchMonitor
    var getSearchMonitorResult: Result<SearchMonitorDetailResponse, Error>?

    /// Result to return from createSearchMonitor
    var createSearchMonitorResult: Result<SearchMonitor, Error>?

    /// Result to return from updateSearchMonitor
    var updateSearchMonitorResult: Result<SearchMonitor, Error>?

    /// Result to return from deleteSearchMonitor
    var deleteSearchMonitorResult: Result<Void, Error> = .success(())

    /// Result to return from listSearchMonitorSummaries
    var listSearchMonitorSummariesResult: Result<[SearchSummary], Error> = .success([])

    /// Result to return from getSearchMonitorSummary
    var getSearchMonitorSummaryResult: Result<SearchSummary, Error>?

    // MARK: - Call Tracking

    /// Number of times listDocuments was called
    private(set) var listDocumentsCallCount = 0

    /// Last classification passed to listDocuments
    private(set) var lastListDocumentsClassification: DocumentClassification?

    /// Last limit passed to listDocuments
    private(set) var lastListDocumentsLimit: Int?

    /// Last cursor passed to listDocuments
    private(set) var lastListDocumentsCursor: String?

    /// Last sort order passed to listDocuments
    private(set) var lastListDocumentsSort: DocumentSortOrder?

    /// Number of times getDocument was called
    private(set) var getDocumentCallCount = 0

    /// Last key passed to getDocument
    private(set) var lastGetDocumentKey: String?

    /// Number of times search was called
    private(set) var searchCallCount = 0

    /// Last query passed to search
    private(set) var lastSearchQuery: String?

    /// Last limit passed to search
    private(set) var lastSearchLimit: Int?

    /// Number of times listTags was called
    private(set) var listTagsCallCount = 0

    /// Number of times documentsByTag was called
    private(set) var documentsByTagCallCount = 0

    /// Last tag passed to documentsByTag
    private(set) var lastDocumentsByTagTag: String?

    /// Last limit passed to documentsByTag
    private(set) var lastDocumentsByTagLimit: Int?

    /// Number of times updateClassification was called
    private(set) var updateClassificationCallCount = 0

    /// Last document ID passed to updateClassification
    private(set) var lastUpdateClassificationDocumentId: String?

    /// Last classification passed to updateClassification
    private(set) var lastUpdateClassificationValue: DocumentClassification?

    /// Number of times createDocument was called
    private(set) var createDocumentCallCount = 0

    /// Number of times updateDocument was called
    private(set) var updateDocumentCallCount = 0

    /// Number of times deleteDocument was called
    private(set) var deleteDocumentCallCount = 0

    /// Number of times listSearchMonitors was called
    private(set) var listSearchMonitorsCallCount = 0

    /// Number of times getSearchMonitor was called
    private(set) var getSearchMonitorCallCount = 0

    /// Last ID passed to getSearchMonitor
    private(set) var lastGetSearchMonitorId: String?

    /// Number of times createSearchMonitor was called
    private(set) var createSearchMonitorCallCount = 0

    /// Last request passed to createSearchMonitor
    private(set) var lastCreateSearchMonitorRequest: SearchMonitorRequest?

    /// Number of times updateSearchMonitor was called
    private(set) var updateSearchMonitorCallCount = 0

    /// Last ID passed to updateSearchMonitor
    private(set) var lastUpdateSearchMonitorId: String?

    /// Last request passed to updateSearchMonitor
    private(set) var lastUpdateSearchMonitorRequest: SearchMonitorRequest?

    /// Number of times deleteSearchMonitor was called
    private(set) var deleteSearchMonitorCallCount = 0

    /// Last ID passed to deleteSearchMonitor
    private(set) var lastDeleteSearchMonitorId: String?

    /// Number of times listSearchMonitorSummaries was called
    private(set) var listSearchMonitorSummariesCallCount = 0

    /// Last monitorId passed to listSearchMonitorSummaries
    private(set) var lastListSearchMonitorSummariesMonitorId: String?

    /// Last limit passed to listSearchMonitorSummaries
    private(set) var lastListSearchMonitorSummariesLimit: Int?

    /// Number of times getSearchMonitorSummary was called
    private(set) var getSearchMonitorSummaryCallCount = 0

    /// Last monitorId passed to getSearchMonitorSummary
    private(set) var lastGetSearchMonitorSummaryMonitorId: String?

    /// Last timestamp passed to getSearchMonitorSummary
    private(set) var lastGetSearchMonitorSummaryTimestamp: String?

    // MARK: - APIClientProtocol

    func listDocuments(
        classification: DocumentClassification?,
        limit: Int,
        cursor: String?,
        sort: DocumentSortOrder? = nil
    ) async throws -> DocumentListResponse {
        listDocumentsCallCount += 1
        lastListDocumentsClassification = classification
        lastListDocumentsLimit = limit
        lastListDocumentsCursor = cursor
        lastListDocumentsSort = sort
        return try listDocumentsResult.get()
    }

    func getDocument(key: String) async throws -> Document {
        getDocumentCallCount += 1
        lastGetDocumentKey = key

        if let result = getDocumentResult {
            return try result.get()
        }
        throw APIError.invalidResponse
    }

    /// Last mode passed to search
    private(set) var lastSearchMode: SearchMode?

    func search(query: String, limit: Int, mode: SearchMode = .keyword) async throws -> [Document] {
        searchCallCount += 1
        lastSearchQuery = query
        lastSearchLimit = limit
        lastSearchMode = mode
        return try searchResult.get()
    }

    func listTags() async throws -> [Tag] {
        listTagsCallCount += 1
        return try listTagsResult.get()
    }

    func listClassifications() async throws -> [ClassificationCount] {
        try listClassificationsResult.get()
    }

    func listSummaries(limit _: Int) async throws -> [Summary] {
        try listSummariesResult.get()
    }

    func listReports(limit _: Int) async throws -> [Report] {
        try listReportsResult.get()
    }

    func documentsByTag(tag: String, limit: Int) async throws -> [Document] {
        documentsByTagCallCount += 1
        lastDocumentsByTagTag = tag
        lastDocumentsByTagLimit = limit
        return try documentsByTagResult.get()
    }

    func updateClassification(
        documentId: String,
        classification: DocumentClassification
    ) async throws {
        updateClassificationCallCount += 1
        lastUpdateClassificationDocumentId = documentId
        lastUpdateClassificationValue = classification
        try updateClassificationResult.get()
    }

    func createDocument(key _: String, title _: String?, content _: String) async throws -> CreateDocumentResponse {
        createDocumentCallCount += 1
        return try createDocumentResult.get()
    }

    func updateDocument(key _: String, content _: String, ifUnmodifiedSince _: String?) async throws {
        updateDocumentCallCount += 1
        try updateDocumentResult.get()
    }

    func deleteDocument(key _: String) async throws {
        deleteDocumentCallCount += 1
        try deleteDocumentResult.get()
    }

    /// Number of times getGraphData was called
    private(set) var getGraphDataCallCount = 0

    func getGraphData() async throws -> GraphDataResponse {
        getGraphDataCallCount += 1
        return try getGraphDataResult.get()
    }

    // MARK: - Search Monitors

    func listSearchMonitors() async throws -> [SearchMonitor] {
        listSearchMonitorsCallCount += 1
        return try listSearchMonitorsResult.get()
    }

    func getSearchMonitor(id: String) async throws -> SearchMonitorDetailResponse {
        getSearchMonitorCallCount += 1
        lastGetSearchMonitorId = id
        if let result = getSearchMonitorResult {
            return try result.get()
        }
        throw APIError.invalidResponse
    }

    func createSearchMonitor(request: SearchMonitorRequest) async throws -> SearchMonitor {
        createSearchMonitorCallCount += 1
        lastCreateSearchMonitorRequest = request
        if let result = createSearchMonitorResult {
            return try result.get()
        }
        throw APIError.invalidResponse
    }

    func updateSearchMonitor(id: String, request: SearchMonitorRequest) async throws -> SearchMonitor {
        updateSearchMonitorCallCount += 1
        lastUpdateSearchMonitorId = id
        lastUpdateSearchMonitorRequest = request
        if let result = updateSearchMonitorResult {
            return try result.get()
        }
        throw APIError.invalidResponse
    }

    func deleteSearchMonitor(id: String) async throws {
        deleteSearchMonitorCallCount += 1
        lastDeleteSearchMonitorId = id
        try deleteSearchMonitorResult.get()
    }

    func listSearchMonitorSummaries(monitorId: String, limit: Int) async throws -> [SearchSummary] {
        listSearchMonitorSummariesCallCount += 1
        lastListSearchMonitorSummariesMonitorId = monitorId
        lastListSearchMonitorSummariesLimit = limit
        return try listSearchMonitorSummariesResult.get()
    }

    func getSearchMonitorSummary(monitorId: String, timestamp: String) async throws -> SearchSummary {
        getSearchMonitorSummaryCallCount += 1
        lastGetSearchMonitorSummaryMonitorId = monitorId
        lastGetSearchMonitorSummaryTimestamp = timestamp
        if let result = getSearchMonitorSummaryResult {
            return try result.get()
        }
        throw APIError.invalidResponse
    }

    // MARK: - Test Helpers

    /// Reset all call counts and captured values
    func reset() {
        listDocumentsCallCount = 0
        lastListDocumentsClassification = nil
        lastListDocumentsLimit = nil
        lastListDocumentsCursor = nil
        lastListDocumentsSort = nil
        getDocumentCallCount = 0
        lastGetDocumentKey = nil
        searchCallCount = 0
        lastSearchQuery = nil
        lastSearchLimit = nil
        lastSearchMode = nil
        listTagsCallCount = 0
        documentsByTagCallCount = 0
        lastDocumentsByTagTag = nil
        lastDocumentsByTagLimit = nil
        updateClassificationCallCount = 0
        lastUpdateClassificationDocumentId = nil
        lastUpdateClassificationValue = nil
        createDocumentCallCount = 0
        updateDocumentCallCount = 0
        deleteDocumentCallCount = 0
        getGraphDataCallCount = 0
        listSearchMonitorsCallCount = 0
        getSearchMonitorCallCount = 0
        lastGetSearchMonitorId = nil
        createSearchMonitorCallCount = 0
        lastCreateSearchMonitorRequest = nil
        updateSearchMonitorCallCount = 0
        lastUpdateSearchMonitorId = nil
        lastUpdateSearchMonitorRequest = nil
        deleteSearchMonitorCallCount = 0
        lastDeleteSearchMonitorId = nil
        listSearchMonitorSummariesCallCount = 0
        lastListSearchMonitorSummariesMonitorId = nil
        lastListSearchMonitorSummariesLimit = nil
        getSearchMonitorSummaryCallCount = 0
        lastGetSearchMonitorSummaryMonitorId = nil
        lastGetSearchMonitorSummaryTimestamp = nil
    }
}
