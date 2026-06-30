@testable import PKMReader

// swiftlint:disable file_length
import XCTest

/// URLProtocol subclass that returns configured responses for testing
private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@MainActor
final class APIClientTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: APIClient!
    private var mockAuthService: MockAuthService!
    private var networkMonitor: NetworkMonitor!
    private var session: URLSession!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mockAuthService = MockAuthService()
        mockAuthService.isAuthenticatedValue = true
        mockAuthService.throwWhenNotAuthenticated = false

        networkMonitor = NetworkMonitor()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)

        sut = APIClient(
            baseURL: URL(string: "https://api.test.com")!,
            authService: mockAuthService,
            networkMonitor: networkMonitor,
            session: session,
            maxRetries: 0,
            baseRetryDelay: 0.01
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockAuthService = nil
        networkMonitor = nil
        session = nil
        MockURLProtocol.requestHandler = nil
        try await super.tearDown()
    }

    // MARK: - Helper

    private func makeJSONResponse(
        url: String = "https://api.test.com/documents",
        statusCode: Int = 200,
        json: Any
    ) -> (HTTPURLResponse, Data) {
        // swiftlint:disable force_unwrapping
        let response = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        // swiftlint:enable force_unwrapping
        let data = try! JSONSerialization.data(withJSONObject: json) // swiftlint:disable:this force_try
        return (response, data)
    }

    // swiftlint:disable force_unwrapping
    private func makeHTTPResponse(
        url: String = "https://api.test.com/documents",
        statusCode: Int
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    private func makeHTTPResponse(
        requestURL: URL,
        statusCode: Int
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: requestURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    private func makeRetryClient() -> APIClient {
        APIClient(
            baseURL: URL(string: "https://api.test.com")!,
            authService: mockAuthService,
            networkMonitor: networkMonitor,
            session: session,
            maxRetries: 1,
            baseRetryDelay: 0.01
        )
    }

    // swiftlint:enable force_unwrapping

    private func sampleDocumentJSON() -> [String: Any] {
        [
            "id": "test.md",
            "title": "Test",
            "content": "# Test",
            "metadata": [
                "classification": "reference",
                "tags": ["test"],
                "linksTo": [] as [String],
                "created": "2024-01-01T00:00:00Z",
                "modified": "2024-01-01T00:00:00Z",
                "hasFrontmatter": true,
            ],
        ]
    }

    // MARK: - listDocuments Tests

    func test_listDocuments_success() async throws {
        MockURLProtocol.requestHandler = { _ in
            self.makeJSONResponse(json: [
                "documents": [self.sampleDocumentJSON()],
                "nextCursor": NSNull(),
            ])
        }

        let response = try await sut.listDocuments(classification: nil, limit: 50, cursor: nil)
        XCTAssertEqual(response.documents.count, 1)
        XCTAssertNil(response.nextCursor)
    }

    func test_listDocuments_withClassification() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("classification=meeting") ?? false)
            return self.makeJSONResponse(json: [
                "documents": [] as [[String: Any]],
                "nextCursor": NSNull(),
            ])
        }

        _ = try await sut.listDocuments(classification: .meeting, limit: 50, cursor: nil)
    }

    func test_listDocuments_withCursor() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("cursor=page2") ?? false)
            return self.makeJSONResponse(json: [
                "documents": [] as [[String: Any]],
                "nextCursor": NSNull(),
            ])
        }

        _ = try await sut.listDocuments(classification: nil, limit: 50, cursor: "page2")
    }

    // MARK: - getDocument Tests

    func test_getDocument_success() async throws {
        MockURLProtocol.requestHandler = { _ in
            self.makeJSONResponse(json: self.sampleDocumentJSON())
        }

        let doc = try await sut.getDocument(key: "test.md")
        XCTAssertEqual(doc.id, "test.md")
        XCTAssertEqual(doc.title, "Test")
    }

    // MARK: - search Tests

    func test_search_success() async throws {
        MockURLProtocol.requestHandler = { _ in
            self.makeJSONResponse(json: [
                "query": "test",
                "results": [self.sampleDocumentJSON()],
                "count": 1,
            ])
        }

        let results = try await sut.search(query: "test", limit: 20)
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - listTags Tests

    func test_listTags_success() async throws {
        MockURLProtocol.requestHandler = { _ in
            self.makeJSONResponse(json: [
                "tags": [["name": "swift", "count": 4]],
                "count": 1,
            ])
        }

        let tags = try await sut.listTags()
        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags.first?.name, "swift")
    }

    // MARK: - listClassifications Tests

    func test_listClassifications_success() async throws {
        MockURLProtocol.requestHandler = { _ in
            self.makeJSONResponse(json: [
                "classifications": [
                    ["name": "meeting", "displayName": "Meeting", "count": 5, "icon": "person.3"],
                ],
            ])
        }

        let classifications = try await sut.listClassifications()
        XCTAssertEqual(classifications.count, 1)
    }

    // MARK: - listSummaries Tests

    func test_listSummaries_success() async throws {
        MockURLProtocol.requestHandler = { _ in
            self.makeJSONResponse(json: [
                "summaries": [
                    ["id": "_agent/summaries/2024-01-01.md", "date": "2024-01-01"],
                ],
                "count": 1,
            ])
        }

        let summaries = try await sut.listSummaries(limit: 30)
        XCTAssertEqual(summaries.count, 1)
    }

    // MARK: - listReports Tests

    func test_listReports_success() async throws {
        MockURLProtocol.requestHandler = { _ in
            self.makeJSONResponse(json: [
                "reports": [
                    ["id": "_agent/reports/2024-01-01.md", "weekOf": "2024-01-01"],
                ],
                "count": 1,
            ])
        }

        let reports = try await sut.listReports(limit: 20)
        XCTAssertEqual(reports.count, 1)
    }

    // MARK: - documentsByTag Tests

    func test_documentsByTag_success() async throws {
        MockURLProtocol.requestHandler = { _ in
            self.makeJSONResponse(json: [
                "tag": "swift",
                "documents": [self.sampleDocumentJSON()],
                "count": 1,
            ])
        }

        let docs = try await sut.documentsByTag(tag: "swift", limit: 50)
        XCTAssertEqual(docs.count, 1)
    }

    // MARK: - Error Handling Tests

    func test_unauthorized_throwsUnauthorized() async {
        MockURLProtocol.requestHandler = { _ in
            (self.makeHTTPResponse(statusCode: 401), Data())
        }

        do {
            _ = try await sut.listDocuments(classification: nil, limit: 50, cursor: nil)
            XCTFail("Expected unauthorized error")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_serverError_throwsHTTPError() async {
        MockURLProtocol.requestHandler = { _ in
            (self.makeHTTPResponse(statusCode: 500), Data())
        }

        do {
            _ = try await sut.listDocuments(classification: nil, limit: 50, cursor: nil)
            XCTFail("Expected HTTP error")
        } catch let error as APIError {
            XCTAssertEqual(error, .httpError(statusCode: 500))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_invalidJSON_throwsDecodingError() async {
        MockURLProtocol.requestHandler = { _ in
            (self.makeHTTPResponse(statusCode: 200), Data("not json".utf8))
        }

        do {
            _ = try await sut.listDocuments(classification: nil, limit: 50, cursor: nil)
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            XCTAssertEqual(error, .decodingError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_notFoundError_throwsHTTPError() async {
        MockURLProtocol.requestHandler = { _ in
            (self.makeHTTPResponse(url: "https://api.test.com/documents/missing", statusCode: 404), Data())
        }

        do {
            _ = try await sut.getDocument(key: "missing")
            XCTFail("Expected HTTP 404 error")
        } catch let error as APIError {
            XCTAssertEqual(error, .httpError(statusCode: 404))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - updateClassification Tests

    func test_updateClassification_success() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertTrue(request.url?.absoluteString.contains("classification") ?? false)
            let url = request.url ?? URL(fileURLWithPath: "/")
            return (self.makeHTTPResponse(requestURL: url, statusCode: 200), Data())
        }

        try await sut.updateClassification(documentId: "test.md", classification: .meeting)
    }

    func test_updateClassification_usesCorrectURL() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("documents/classification/test.md") ?? false)
            let url = request.url ?? URL(fileURLWithPath: "/")
            return (self.makeHTTPResponse(requestURL: url, statusCode: 200), Data())
        }

        try await sut.updateClassification(documentId: "test.md", classification: .idea)
    }

    // MARK: - Retry Tests

    func test_retryableError_retriesAndSucceeds() async throws {
        let retryClient = makeRetryClient()
        var attemptCount = 0
        MockURLProtocol.requestHandler = { _ in
            attemptCount += 1
            if attemptCount == 1 {
                return (self.makeHTTPResponse(statusCode: 500), Data())
            }
            return self.makeJSONResponse(json: [
                "documents": [self.sampleDocumentJSON()],
                "nextCursor": NSNull(),
            ])
        }

        let response = try await retryClient.listDocuments(classification: nil, limit: 50, cursor: nil)
        XCTAssertEqual(response.documents.count, 1)
        XCTAssertEqual(attemptCount, 2)
    }

    func test_putRetryableError_retriesAndSucceeds() async throws {
        let retryClient = makeRetryClient()
        var attemptCount = 0
        MockURLProtocol.requestHandler = { request in
            attemptCount += 1
            if attemptCount == 1 {
                let url = request.url ?? URL(fileURLWithPath: "/")
                return (self.makeHTTPResponse(requestURL: url, statusCode: 500), Data())
            }
            let url = request.url ?? URL(fileURLWithPath: "/")
            return (self.makeHTTPResponse(requestURL: url, statusCode: 200), Data())
        }

        try await retryClient.updateClassification(documentId: "test.md", classification: .meeting)
        XCTAssertEqual(attemptCount, 2)
    }

    func test_retryExhausted_throwsLastError() async {
        let retryClient = makeRetryClient()
        MockURLProtocol.requestHandler = { _ in
            (self.makeHTTPResponse(statusCode: 503), Data())
        }

        do {
            _ = try await retryClient.listDocuments(classification: nil, limit: 50, cursor: nil)
            XCTFail("Expected HTTP error after retries exhausted")
        } catch let error as APIError {
            XCTAssertEqual(error, .httpError(statusCode: 503))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_putRetryExhausted_throwsLastError() async {
        let retryClient = makeRetryClient()
        MockURLProtocol.requestHandler = { request in
            (self.makeHTTPResponse(requestURL: request.url ?? URL(fileURLWithPath: "/"), statusCode: 503), Data())
        }

        do {
            try await retryClient.updateClassification(documentId: "test.md", classification: .meeting)
            XCTFail("Expected HTTP error after retries exhausted")
        } catch let error as APIError {
            XCTAssertEqual(error, .httpError(statusCode: 503))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - URLError Handling Tests

    func test_urlError_timeout_throwsTimeout() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.timedOut) }

        do {
            _ = try await sut.listDocuments(classification: nil, limit: 50, cursor: nil)
            XCTFail("Expected timeout error")
        } catch let error as APIError {
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_urlError_notConnected_throwsNetworkError() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }

        do {
            _ = try await sut.listDocuments(classification: nil, limit: 50, cursor: nil)
            XCTFail("Expected network error")
        } catch let error as APIError {
            XCTAssertEqual(error, .networkError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_urlError_other_throwsNetworkError() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.badServerResponse) }

        do {
            _ = try await sut.listDocuments(classification: nil, limit: 50, cursor: nil)
            XCTFail("Expected network error")
        } catch let error as APIError {
            XCTAssertEqual(error, .networkError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_put_urlError_timeout_throwsTimeout() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.timedOut) }

        do {
            try await sut.updateClassification(documentId: "test.md", classification: .meeting)
            XCTFail("Expected timeout error")
        } catch let error as APIError {
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_put_urlError_networkLost_throwsNetworkError() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.networkConnectionLost) }

        do {
            try await sut.updateClassification(documentId: "test.md", classification: .meeting)
            XCTFail("Expected network error")
        } catch let error as APIError {
            XCTAssertEqual(error, .networkError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_put_unauthorized_throwsUnauthorized() async {
        MockURLProtocol.requestHandler = { request in
            (self.makeHTTPResponse(requestURL: request.url ?? URL(fileURLWithPath: "/"), statusCode: 401), Data())
        }

        do {
            try await sut.updateClassification(documentId: "test.md", classification: .meeting)
            XCTFail("Expected unauthorized error")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_put_notFound_throwsHTTPError() async {
        MockURLProtocol.requestHandler = { request in
            (self.makeHTTPResponse(requestURL: request.url ?? URL(fileURLWithPath: "/"), statusCode: 404), Data())
        }

        do {
            try await sut.updateClassification(documentId: "test.md", classification: .meeting)
            XCTFail("Expected HTTP 404 error")
        } catch let error as APIError {
            XCTAssertEqual(error, .httpError(statusCode: 404))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Authorization Header Tests

    func test_request_includesAuthorizationHeader() async throws {
        mockAuthService.accessToken = "test-token-123"

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            return self.makeJSONResponse(json: [
                "documents": [] as [[String: Any]],
                "nextCursor": NSNull(),
            ])
        }

        _ = try await sut.listDocuments(classification: nil, limit: 50, cursor: nil)
    }
}
