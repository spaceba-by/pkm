import Foundation
@testable import PKMReader

/// Mock authentication service for unit testing
final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {
    // MARK: - Configurable State

    /// Current authentication state
    var isAuthenticatedValue = false

    /// Result to return from signIn
    var signInResult: Result<Void, Error> = .success(())

    /// Result to return from signOut
    var signOutResult: Result<Void, Error> = .success(())

    /// Token to return from getAccessToken
    var accessToken = "mock-access-token"

    /// Whether to throw from getAccessToken when not authenticated
    var throwWhenNotAuthenticated = true

    // MARK: - Call Tracking

    /// Number of times signIn was called
    private(set) var signInCallCount = 0

    /// Last email passed to signIn
    private(set) var lastSignInEmail: String?

    /// Last password passed to signIn
    private(set) var lastSignInPassword: String?

    /// Number of times signOut was called
    private(set) var signOutCallCount = 0

    /// Number of times getAccessToken was called
    private(set) var getAccessTokenCallCount = 0

    // MARK: - AuthServiceProtocol

    var isAuthenticated: Bool {
        isAuthenticatedValue
    }

    func signIn(email: String, password: String) async throws {
        signInCallCount += 1
        lastSignInEmail = email
        lastSignInPassword = password
        try signInResult.get()
        isAuthenticatedValue = true
    }

    func signOut() async throws {
        signOutCallCount += 1
        try signOutResult.get()
        isAuthenticatedValue = false
    }

    func getAccessToken() async throws -> String {
        getAccessTokenCallCount += 1
        if throwWhenNotAuthenticated && !isAuthenticatedValue {
            throw AuthError.notAuthenticated
        }
        return accessToken
    }

    // MARK: - Test Helpers

    /// Reset all call counts and captured values
    func reset() {
        signInCallCount = 0
        lastSignInEmail = nil
        lastSignInPassword = nil
        signOutCallCount = 0
        getAccessTokenCallCount = 0
        isAuthenticatedValue = false
    }
}
