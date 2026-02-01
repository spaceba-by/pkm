import Foundation

/// Protocol defining the keychain service interface for testability
protocol KeychainServiceProtocol: Sendable {
    /// Save a value to the keychain
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The key to store the value under
    func save(_ value: String, forKey key: String) throws

    /// Retrieve a value from the keychain
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: The stored value, or nil if not found
    func retrieve(forKey key: String) throws -> String?

    /// Delete a value from the keychain
    /// - Parameter key: The key to delete
    func delete(forKey key: String) throws
}

/// Common keychain keys used by the app
enum KeychainKey {
    static let accessToken = "pkm.accessToken"
    static let refreshToken = "pkm.refreshToken"
    static let idToken = "pkm.idToken"
}

/// Errors that can occur during keychain operations
enum KeychainError: Error, Sendable {
    case unableToSave
    case unableToRetrieve
    case unableToDelete
    case dataConversionError
}
