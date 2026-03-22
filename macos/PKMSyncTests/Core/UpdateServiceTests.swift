@testable import PKMSync
import XCTest

final class UpdateServiceTests: XCTestCase {
    private var sut: GitHubUpdateService!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        sut = GitHubUpdateService(session: session)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testCheckForUpdateFindsNewerVersion() async throws {
        let json = """
        [
            {
                "tag_name": "macos-v1.1.0",
                "name": "macOS v1.1.0",
                "body": "Bug fixes",
                "draft": false,
                "prerelease": false,
                "published_at": "2026-03-20T12:00:00Z",
                "assets": [
                    {
                        "name": "PKMSync.zip",
                        "size": 5000000,
                        "browser_download_url": "https://example.com/PKMSync.zip"
                    }
                ]
            }
        ]
        """
        MockURLProtocol.requestHandler = { _ in
            let data = json.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: URL(string: "https://api.github.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }

        let update = try await sut.checkForUpdate(currentVersion: "1.0.0")

        XCTAssertNotNil(update)
        XCTAssertEqual(update?.version, "1.1.0")
        XCTAssertEqual(update?.releaseNotes, "Bug fixes")
    }

    func testCheckForUpdateReturnsNilWhenUpToDate() async throws {
        let json = """
        [
            {
                "tag_name": "macos-v1.0.0",
                "name": "macOS v1.0.0",
                "body": "Initial release",
                "draft": false,
                "prerelease": false,
                "published_at": "2026-03-15T12:00:00Z",
                "assets": [
                    {
                        "name": "PKMSync.zip",
                        "size": 5000000,
                        "browser_download_url": "https://example.com/PKMSync.zip"
                    }
                ]
            }
        ]
        """
        MockURLProtocol.requestHandler = { _ in
            let data = json.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: URL(string: "https://api.github.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }

        let update = try await sut.checkForUpdate(currentVersion: "1.0.0")

        XCTAssertNil(update)
    }

    func testCheckForUpdateSkipsDraftsAndPrereleases() async throws {
        let json = """
        [
            {
                "tag_name": "macos-v2.0.0",
                "name": "macOS v2.0.0-beta",
                "body": "Beta",
                "draft": false,
                "prerelease": true,
                "published_at": "2026-03-20T12:00:00Z",
                "assets": [{"name": "PKMSync.zip", "size": 100, "browser_download_url": "https://example.com/PKMSync.zip"}]
            },
            {
                "tag_name": "macos-v1.5.0",
                "name": "Draft",
                "body": "Draft",
                "draft": true,
                "prerelease": false,
                "published_at": "2026-03-19T12:00:00Z",
                "assets": [{"name": "PKMSync.zip", "size": 100, "browser_download_url": "https://example.com/PKMSync.zip"}]
            }
        ]
        """
        MockURLProtocol.requestHandler = { _ in
            let data = json.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: URL(string: "https://api.github.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }

        let update = try await sut.checkForUpdate(currentVersion: "1.0.0")
        XCTAssertNil(update)
    }

    func testCheckForUpdateSkipsNonMacosReleases() async throws {
        let json = """
        [
            {
                "tag_name": "ios-v5.0.0",
                "name": "iOS v5.0.0",
                "body": "iOS release",
                "draft": false,
                "prerelease": false,
                "published_at": "2026-03-20T12:00:00Z",
                "assets": [{"name": "PKMSync.zip", "size": 100, "browser_download_url": "https://example.com/PKMSync.zip"}]
            }
        ]
        """
        MockURLProtocol.requestHandler = { _ in
            let data = json.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: URL(string: "https://api.github.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }

        let update = try await sut.checkForUpdate(currentVersion: "1.0.0")
        XCTAssertNil(update)
    }

    func testCheckForUpdateThrowsOnNetworkError() async {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://api.github.com")!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        do {
            _ = try await sut.checkForUpdate(currentVersion: "1.0.0")
            XCTFail("Expected error")
        } catch {
            // Expected
        }
    }
}

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override static func canInit(with _: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
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
