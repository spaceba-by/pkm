@testable import PKMReader

// swiftlint:disable force_unwrapping force_try
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
final class APIClientNotificationTests: XCTestCase {
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

    // MARK: - Helpers

    private func makeHTTPResponse(requestURL: URL, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: requestURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    private func makeJSONResponse(
        url: String,
        statusCode: Int = 200,
        json: Any
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let data = try! JSONSerialization.data(withJSONObject: json)
        return (response, data)
    }

    // MARK: - registerDevice Tests

    func test_registerDevice_success() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url?.absoluteString.contains("devices") ?? false)
            let url = request.url ?? URL(fileURLWithPath: "/")
            let responseJSON: [String: Any] = ["deviceId": "device-001", "registered": true]
            let data = try! JSONSerialization.data(withJSONObject: responseJSON)
            return (self.makeHTTPResponse(requestURL: url, statusCode: 200), data)
        }

        let request = DeviceRegistrationRequest(
            deviceToken: "abc123",
            deviceId: "device-001",
            platform: "ios",
            appVersion: "1.0.0"
        )
        let response = try await sut.registerDevice(request: request)
        XCTAssertEqual(response.deviceId, "device-001")
        XCTAssertTrue(response.registered)
    }

    func test_registerDevice_usesCorrectURL() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.hasSuffix("/devices") ?? false)
            let url = request.url ?? URL(fileURLWithPath: "/")
            let responseJSON: [String: Any] = ["deviceId": "dev-1", "registered": true]
            let data = try! JSONSerialization.data(withJSONObject: responseJSON)
            return (self.makeHTTPResponse(requestURL: url, statusCode: 200), data)
        }

        let request = DeviceRegistrationRequest(
            deviceToken: "token-xyz",
            deviceId: "dev-1",
            platform: "ios",
            appVersion: "2.0.0"
        )
        _ = try await sut.registerDevice(request: request)
    }

    // MARK: - unregisterDevice Tests

    func test_unregisterDevice_success() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertTrue(request.url?.absoluteString.contains("devices/device-001") ?? false)
            let url = request.url ?? URL(fileURLWithPath: "/")
            return (self.makeHTTPResponse(requestURL: url, statusCode: 200), Data("{}".utf8))
        }

        try await sut.unregisterDevice(deviceId: "device-001")
    }

    func test_unregisterDevice_serverError_throws() async {
        MockURLProtocol.requestHandler = { request in
            (self.makeHTTPResponse(requestURL: request.url ?? URL(fileURLWithPath: "/"), statusCode: 500), Data())
        }

        do {
            try await sut.unregisterDevice(deviceId: "device-001")
            XCTFail("Expected HTTP error")
        } catch let error as APIError {
            XCTAssertEqual(error, .httpError(statusCode: 500))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - listNotifications Tests

    func test_listNotifications_success() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("notifications") ?? false)
            return self.makeJSONResponse(
                url: "https://api.test.com/notifications",
                json: [
                    "notifications": [
                        [
                            "notificationId": "notif-001",
                            "notificationType": "daily_summary",
                            "title": "Daily Summary",
                            "body": "Summary of 5 docs",
                            "deepLink": "/summaries/2026-02-23",
                            "timestamp": "2026-02-23T06:00:00Z",
                            "read": false,
                        ],
                    ],
                    "count": 1,
                ]
            )
        }

        let response = try await sut.listNotifications()
        XCTAssertEqual(response.count, 1)
        XCTAssertEqual(response.notifications.count, 1)
        XCTAssertEqual(response.notifications[0].notificationId, "notif-001")
        XCTAssertFalse(response.notifications[0].read)
    }

    func test_listNotifications_empty() async throws {
        MockURLProtocol.requestHandler = { _ in
            self.makeJSONResponse(
                url: "https://api.test.com/notifications",
                json: ["notifications": [] as [[String: Any]], "count": 0]
            )
        }

        let response = try await sut.listNotifications()
        XCTAssertEqual(response.count, 0)
        XCTAssertTrue(response.notifications.isEmpty)
    }

    // MARK: - markNotificationRead Tests

    func test_markNotificationRead_success() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertTrue(request.url?.absoluteString.contains("notifications/notif-001/read") ?? false)
            let url = request.url ?? URL(fileURLWithPath: "/")
            return (self.makeHTTPResponse(requestURL: url, statusCode: 200), Data("{}".utf8))
        }

        try await sut.markNotificationRead(id: "notif-001")
    }

    func test_markNotificationRead_serverError_throws() async {
        MockURLProtocol.requestHandler = { request in
            (self.makeHTTPResponse(requestURL: request.url ?? URL(fileURLWithPath: "/"), statusCode: 500), Data())
        }

        do {
            try await sut.markNotificationRead(id: "notif-001")
            XCTFail("Expected HTTP error")
        } catch let error as APIError {
            XCTAssertEqual(error, .httpError(statusCode: 500))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// swiftlint:enable force_unwrapping force_try
