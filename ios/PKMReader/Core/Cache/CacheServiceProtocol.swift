import Foundation

/// Protocol defining the cache service interface for testability
protocol CacheServiceProtocol: Sendable {
    /// Get a cached value by key
    /// - Parameter key: The cache key
    /// - Returns: The cached value, or nil if not found or expired
    func get<T: Codable>(key: String) async -> T?

    /// Store a value in the cache
    /// - Parameters:
    ///   - key: The cache key
    ///   - value: The value to cache
    func set(key: String, value: some Codable) async

    /// Remove a cached value
    /// - Parameter key: The cache key to remove
    func remove(key: String) async

    /// Clear all cached values
    func clear() async
}

/// Common cache keys used by the app
enum CacheKey {
    static let documentList = "documents.list"
    static let tags = "tags.list"

    static func document(id: String) -> String {
        "document.\(id)"
    }

    static func documentsByTag(tag: String) -> String {
        "documents.tag.\(tag)"
    }

    static func documentsByClassification(classification: DocumentClassification) -> String {
        "documents.classification.\(classification.rawValue)"
    }
}
