@testable import PKMReader
import XCTest

final class AppConfigTests: XCTestCase {
    func test_apiBaseURL_usesHTTPS() {
        XCTAssertEqual(AppConfig.apiBaseURL.scheme, "https")
    }

    func test_cognitoUserPoolId_isNotEmpty() {
        XCTAssertFalse(AppConfig.cognitoUserPoolId.isEmpty)
    }

    func test_cognitoClientId_isNotEmpty() {
        XCTAssertFalse(AppConfig.cognitoClientId.isEmpty)
    }

    func test_cognitoIdentityPoolId_isNotEmpty() {
        XCTAssertFalse(AppConfig.cognitoIdentityPoolId.isEmpty)
    }

    func test_cognitoRegion_isUSEast1() {
        XCTAssertEqual(AppConfig.cognitoRegion, "us-east-1")
    }

    func test_appVersion_isNotEmpty() {
        XCTAssertFalse(AppConfig.appVersion.isEmpty)
    }

    func test_buildNumber_isNotEmpty() {
        XCTAssertFalse(AppConfig.buildNumber.isEmpty)
    }
}
