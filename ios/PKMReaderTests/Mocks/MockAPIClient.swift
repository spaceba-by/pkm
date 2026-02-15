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

    // MARK: - Call Tracking

    /// Number of times listDocuments was called
    private(set) var listDocumentsCallCount = 0

    /// Last classification passed to listDocuments
    private(set) var lastListDocumentsClassification: DocumentClassification?

    /// Last limit passed to listDocuments
    private(set) var lastListDocumentsLimit: Int?

    /// Last cursor passed to listDocuments
    private(set) var lastListDocumentsCursor: String?

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

    // MARK: - APIClientProtocol

    func listDocuments(
        classification: DocumentClassification?,
        limit: Int,
        cursor: String?
    ) async throws -> DocumentListResponse {
        listDocumentsCallCount += 1
        lastListDocumentsClassification = classification
        lastListDocumentsLimit = limit
        lastListDocumentsCursor = cursor
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

    func search(query: String, limit: Int) async throws -> [Document] {
        searchCallCount += 1
        lastSearchQuery = query
        lastSearchLimit = limit
        return try searchResult.get()
    }

    func listTags() async throws -> [Tag] {
        listTagsCallCount += 1
        return try listTagsResult.get()
    }

    func listClassifications() async throws -> [ClassificationCount] {
        try listClassificationsResult.get()
    }

    func listSummaries(limit: Int) async throws -> [Summary] {
        try listSummariesResult.get()
    }

    func listReports(limit: Int) async throws -> [Report] {
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

    // MARK: - Test Helpers

    /// Reset all call counts and captured values
    func reset() {
        listDocumentsCallCount = 0
        lastListDocumentsClassification = nil
        lastListDocumentsLimit = nil
        lastListDocumentsCursor = nil
        getDocumentCallCount = 0
        lastGetDocumentKey = nil
        searchCallCount = 0
        lastSearchQuery = nil
        lastSearchLimit = nil
        listTagsCallCount = 0
        documentsByTagCallCount = 0
        lastDocumentsByTagTag = nil
        lastDocumentsByTagLimit = nil
        updateClassificationCallCount = 0
        lastUpdateClassificationDocumentId = nil
        lastUpdateClassificationValue = nil
    }
}
