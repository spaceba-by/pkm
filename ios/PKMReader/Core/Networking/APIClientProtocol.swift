import Foundation

/// Protocol defining the API client interface for testability
protocol APIClientProtocol: Sendable {
    /// List documents with optional filtering and pagination
    /// - Parameters:
    ///   - classification: Optional classification to filter by
    ///   - limit: Maximum number of documents to return
    ///   - cursor: Pagination cursor from previous response
    /// - Returns: Response containing documents and optional next cursor
    func listDocuments(
        classification: DocumentClassification?,
        limit: Int,
        cursor: String?
    ) async throws -> DocumentListResponse

    /// Get a single document by its key
    /// - Parameter key: The document's S3 key
    /// - Returns: The document with content loaded
    func getDocument(key: String) async throws -> Document

    /// Search documents by query
    /// - Parameters:
    ///   - query: Search query string
    ///   - limit: Maximum number of results
    /// - Returns: List of matching documents
    func search(query: String, limit: Int) async throws -> [Document]

    /// List all tags in the vault
    /// - Returns: List of tags with document counts
    func listTags() async throws -> [Tag]
}
