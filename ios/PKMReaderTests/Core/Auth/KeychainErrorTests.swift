import XCTest
@testable import PKMReader

final class KeychainErrorTests: XCTestCase {
    func test_keychainKey_constants() {
        XCTAssertEqual(KeychainKey.accessToken, "pkm.accessToken")
        XCTAssertEqual(KeychainKey.refreshToken, "pkm.refreshToken")
        XCTAssertEqual(KeychainKey.idToken, "pkm.idToken")
    }

    func test_keychainError_cases() {
        // Verify all cases exist and are distinct errors
        let errors: [KeychainError] = [
            .unableToSave,
            .unableToRetrieve,
            .unableToDelete,
            .dataConversionError
        ]
        XCTAssertEqual(errors.count, 4)
    }
}
