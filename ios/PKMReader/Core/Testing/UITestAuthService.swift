#if DEBUG
import Foundation

/// Mock auth service for UI testing that simulates an authenticated state
/// Activated via the `--mock-api` launch argument
final class UITestAuthService: AuthServiceProtocol, @unchecked Sendable {
    var isAuthenticated: Bool { true }

    func signIn(email: String, password: String) async throws {
        // No-op for UI tests
    }

    func signOut() async throws {
        // No-op for UI tests
    }

    func getAccessToken() async throws -> String {
        "uitest-mock-token"
    }
}
#endif
