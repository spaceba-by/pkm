import Foundation
@testable import PKMReader

/// Mock keychain service for unit testing
final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    // MARK: - Storage

    /// In-memory storage for keychain values
    private var storage: [String: String] = [:]

    // MARK: - Error Configuration

    /// Error to throw from save operations
    var saveError: KeychainError?

    /// Error to throw from retrieve operations
    var retrieveError: KeychainError?

    /// Error to throw from delete operations
    var deleteError: KeychainError?

    // MARK: - Call Tracking

    /// Number of times save was called
    private(set) var saveCallCount = 0

    /// Last key passed to save
    private(set) var lastSaveKey: String?

    /// Number of times retrieve was called
    private(set) var retrieveCallCount = 0

    /// Last key passed to retrieve
    private(set) var lastRetrieveKey: String?

    /// Number of times delete was called
    private(set) var deleteCallCount = 0

    /// Last key passed to delete
    private(set) var lastDeleteKey: String?

    // MARK: - KeychainServiceProtocol

    func save(_ value: String, forKey key: String) throws {
        saveCallCount += 1
        lastSaveKey = key

        if let error = saveError {
            throw error
        }

        storage[key] = value
    }

    func retrieve(forKey key: String) throws -> String? {
        retrieveCallCount += 1
        lastRetrieveKey = key

        if let error = retrieveError {
            throw error
        }

        return storage[key]
    }

    func delete(forKey key: String) throws {
        deleteCallCount += 1
        lastDeleteKey = key

        if let error = deleteError {
            throw error
        }

        storage.removeValue(forKey: key)
    }

    // MARK: - Test Helpers

    /// Reset all storage, call counts, and captured values
    func reset() {
        storage.removeAll()
        saveError = nil
        retrieveError = nil
        deleteError = nil
        saveCallCount = 0
        lastSaveKey = nil
        retrieveCallCount = 0
        lastRetrieveKey = nil
        deleteCallCount = 0
        lastDeleteKey = nil
    }

    /// Get all stored values (for testing)
    var allStoredValues: [String: String] {
        storage
    }
}
