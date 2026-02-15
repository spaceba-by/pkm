import XCTest
@testable import PKMReader

final class APIErrorTests: XCTestCase {
    // MARK: - isRetryable

    func test_networkError_isRetryable() {
        XCTAssertTrue(APIError.networkError.isRetryable)
    }

    func test_timeout_isRetryable() {
        XCTAssertTrue(APIError.timeout.isRetryable)
    }

    func test_httpError500_isRetryable() {
        XCTAssertTrue(APIError.httpError(statusCode: 500).isRetryable)
    }

    func test_httpError502_isRetryable() {
        XCTAssertTrue(APIError.httpError(statusCode: 502).isRetryable)
    }

    func test_httpError503_isRetryable() {
        XCTAssertTrue(APIError.httpError(statusCode: 503).isRetryable)
    }

    func test_httpError429_isRetryable() {
        XCTAssertTrue(APIError.httpError(statusCode: 429).isRetryable)
    }

    func test_httpError404_isNotRetryable() {
        XCTAssertFalse(APIError.httpError(statusCode: 404).isRetryable)
    }

    func test_unauthorized_isNotRetryable() {
        XCTAssertFalse(APIError.unauthorized.isRetryable)
    }

    func test_decodingError_isNotRetryable() {
        XCTAssertFalse(APIError.decodingError.isRetryable)
    }

    func test_invalidURL_isNotRetryable() {
        XCTAssertFalse(APIError.invalidURL.isRetryable)
    }

    func test_invalidResponse_isNotRetryable() {
        XCTAssertFalse(APIError.invalidResponse.isRetryable)
    }

    func test_serverError_isNotRetryable() {
        XCTAssertFalse(APIError.serverError("test").isRetryable)
    }

    // MARK: - isNetworkError

    func test_networkError_isNetworkError() {
        XCTAssertTrue(APIError.networkError.isNetworkError)
    }

    func test_timeout_isNetworkError() {
        XCTAssertTrue(APIError.timeout.isNetworkError)
    }

    func test_httpError_isNotNetworkError() {
        XCTAssertFalse(APIError.httpError(statusCode: 500).isNetworkError)
    }

    func test_unauthorized_isNotNetworkError() {
        XCTAssertFalse(APIError.unauthorized.isNetworkError)
    }

    func test_decodingError_isNotNetworkError() {
        XCTAssertFalse(APIError.decodingError.isNetworkError)
    }

    // MARK: - Error Descriptions

    func test_networkError_hasUserFriendlyDescription() {
        let description = APIError.networkError.errorDescription ?? ""
        XCTAssertTrue(description.contains("internet"))
    }

    func test_timeout_hasUserFriendlyDescription() {
        let description = APIError.timeout.errorDescription ?? ""
        XCTAssertTrue(description.contains("timed out"))
    }

    func test_unauthorized_hasUserFriendlyDescription() {
        let description = APIError.unauthorized.errorDescription ?? ""
        XCTAssertTrue(description.contains("session"))
    }

    func test_httpError429_mentionsRateLimit() {
        let description = APIError.httpError(statusCode: 429).errorDescription ?? ""
        XCTAssertTrue(description.contains("many requests"))
    }

    func test_httpError500_mentionsServer() {
        let description = APIError.httpError(statusCode: 500).errorDescription ?? ""
        XCTAssertTrue(description.contains("server"))
    }

    func test_invalidURL_hasDescription() {
        let description = APIError.invalidURL.errorDescription ?? ""
        XCTAssertTrue(description.contains("URL"))
    }

    func test_invalidResponse_hasDescription() {
        let description = APIError.invalidResponse.errorDescription ?? ""
        XCTAssertTrue(description.contains("unexpected"))
    }

    func test_decodingError_hasDescription() {
        let description = APIError.decodingError.errorDescription ?? ""
        XCTAssertTrue(description.contains("could not be read"))
    }

    func test_serverError_returnsMessage() {
        let message = "Custom error message"
        XCTAssertEqual(APIError.serverError(message).errorDescription, message)
    }

    func test_httpError403_hasGenericDescription() {
        let description = APIError.httpError(statusCode: 403).errorDescription ?? ""
        XCTAssertTrue(description.contains("403"))
    }
}
