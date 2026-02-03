import Foundation

/// Represents the current authentication state of the app
enum AuthState: Equatable, Sendable {
    /// Initial state before checking authentication
    case unknown

    /// User is signed in
    case signedIn

    /// User is signed out
    case signedOut
}
