import Foundation

/// Protocol defining the authentication service interface for testability
protocol AuthServiceProtocol: Sendable {
    /// Whether the user is currently authenticated
    var isAuthenticated: Bool { get async }

    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    func signIn(email: String, password: String) async throws

    /// Sign out the current user
    func signOut() async throws

    /// Get the current access token for API requests
    /// - Returns: The access token string
    func getAccessToken() async throws -> String
}

/// Errors that can occur during authentication
enum AuthError: Error, Equatable, Sendable {
    /// User is not authenticated
    case notAuthenticated

    /// Invalid email or password
    case invalidCredentials

    /// Account is not confirmed
    case accountNotConfirmed

    /// Network error during authentication
    case networkError

    /// User already exists
    case userAlreadyExists

    /// Password doesn't meet requirements
    case invalidPassword

    /// Unknown authentication error
    case unknown(String)
}

extension AuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .invalidCredentials:
            return "Invalid email or password"
        case .accountNotConfirmed:
            return "Please confirm your account"
        case .networkError:
            return "Network error"
        case .userAlreadyExists:
            return "An account with this email already exists"
        case .invalidPassword:
            return "Password doesn't meet requirements"
        case .unknown(let message):
            return message
        }
    }
}
