@testable import PKMReader
import XCTest

final class AuthErrorTests: XCTestCase {
    // MARK: - Equatable

    func test_equatable_sameCase() {
        XCTAssertEqual(AuthError.notAuthenticated, AuthError.notAuthenticated)
        XCTAssertEqual(AuthError.invalidCredentials, AuthError.invalidCredentials)
        XCTAssertEqual(AuthError.accountNotConfirmed, AuthError.accountNotConfirmed)
        XCTAssertEqual(AuthError.networkError, AuthError.networkError)
        XCTAssertEqual(AuthError.userAlreadyExists, AuthError.userAlreadyExists)
        XCTAssertEqual(AuthError.invalidPassword, AuthError.invalidPassword)
    }

    func test_equatable_differentCase() {
        XCTAssertNotEqual(AuthError.notAuthenticated, AuthError.invalidCredentials)
        XCTAssertNotEqual(AuthError.networkError, AuthError.invalidPassword)
    }

    func test_equatable_unknown_sameMessage() {
        XCTAssertEqual(AuthError.unknown("test"), AuthError.unknown("test"))
    }

    func test_equatable_unknown_differentMessage() {
        XCTAssertNotEqual(AuthError.unknown("a"), AuthError.unknown("b"))
    }

    // MARK: - Error Descriptions

    func test_notAuthenticated_description() {
        XCTAssertEqual(AuthError.notAuthenticated.errorDescription, "Not authenticated")
    }

    func test_invalidCredentials_description() {
        XCTAssertEqual(AuthError.invalidCredentials.errorDescription, "Invalid email or password")
    }

    func test_accountNotConfirmed_description() {
        XCTAssertEqual(AuthError.accountNotConfirmed.errorDescription, "Please confirm your account")
    }

    func test_networkError_description() {
        XCTAssertEqual(AuthError.networkError.errorDescription, "Network error")
    }

    func test_userAlreadyExists_description() {
        XCTAssertEqual(AuthError.userAlreadyExists.errorDescription, "An account with this email already exists")
    }

    func test_invalidPassword_description() {
        XCTAssertEqual(AuthError.invalidPassword.errorDescription, "Password doesn't meet requirements")
    }

    func test_unknown_description() {
        let message = "Something went wrong"
        XCTAssertEqual(AuthError.unknown(message).errorDescription, message)
    }
}
