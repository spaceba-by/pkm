import Foundation
@testable import PKMReader

/// Mock cache service for unit testing
final class MockCacheService: CacheServiceProtocol, @unchecked Sendable {
    // MARK: - Storage

    /// In-memory storage for cached values
    private var storage: [String: Data] = [:]

    // MARK: - Call Tracking

    /// Number of times get was called
    private(set) var getCallCount = 0

    /// Last key passed to get
    private(set) var lastGetKey: String?

    /// Number of times set was called
    private(set) var setCallCount = 0

    /// Last key passed to set
    private(set) var lastSetKey: String?

    /// Number of times remove was called
    private(set) var removeCallCount = 0

    /// Last key passed to remove
    private(set) var lastRemoveKey: String?

    /// Number of times clear was called
    private(set) var clearCallCount = 0

    // MARK: - CacheServiceProtocol

    func get<T: Codable>(key: String) async -> T? {
        getCallCount += 1
        lastGetKey = key

        guard let data = storage[key] else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func set<T: Codable>(key: String, value: T) async {
        setCallCount += 1
        lastSetKey = key

        if let data = try? JSONEncoder().encode(value) {
            storage[key] = data
        }
    }

    func remove(key: String) async {
        removeCallCount += 1
        lastRemoveKey = key
        storage.removeValue(forKey: key)
    }

    func clear() async {
        clearCallCount += 1
        storage.removeAll()
    }

    // MARK: - Test Helpers

    /// Reset all storage, call counts, and captured values
    func reset() {
        storage.removeAll()
        getCallCount = 0
        lastGetKey = nil
        setCallCount = 0
        lastSetKey = nil
        removeCallCount = 0
        lastRemoveKey = nil
        clearCallCount = 0
    }

    /// Check if a key exists in the cache (for testing)
    func contains(key: String) -> Bool {
        storage[key] != nil
    }
}
