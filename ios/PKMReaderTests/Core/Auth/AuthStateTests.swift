@testable import PKMReader
import XCTest

final class AuthStateTests: XCTestCase {
    func test_equatable() {
        XCTAssertEqual(AuthState.unknown, AuthState.unknown)
        XCTAssertEqual(AuthState.signedIn, AuthState.signedIn)
        XCTAssertEqual(AuthState.signedOut, AuthState.signedOut)
    }

    func test_notEqual() {
        XCTAssertNotEqual(AuthState.unknown, AuthState.signedIn)
        XCTAssertNotEqual(AuthState.signedIn, AuthState.signedOut)
        XCTAssertNotEqual(AuthState.signedOut, AuthState.unknown)
    }
}
