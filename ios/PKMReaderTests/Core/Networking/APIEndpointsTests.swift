@testable import PKMReader
import XCTest

final class APIEndpointsTests: XCTestCase {
    // MARK: - Documents Endpoint

    func test_documents_defaultParameters() {
        let path = APIEndpoints.documents()
        XCTAssertEqual(path, "/documents?limit=50")
    }

    func test_documents_withClassification() {
        let path = APIEndpoints.documents(classification: .meeting)
        XCTAssertTrue(path.contains("classification=meeting"))
        XCTAssertTrue(path.contains("limit=50"))
    }

    func test_documents_withCustomLimit() {
        let path = APIEndpoints.documents(limit: 10)
        XCTAssertTrue(path.contains("limit=10"))
    }

    func test_documents_withCursor() {
        let path = APIEndpoints.documents(cursor: "abc123")
        XCTAssertTrue(path.contains("cursor=abc123"))
    }

    func test_documents_withAllParameters() {
        let path = APIEndpoints.documents(
            classification: .idea,
            limit: 25,
            cursor: "page2"
        )
        XCTAssertTrue(path.contains("classification=idea"))
        XCTAssertTrue(path.contains("limit=25"))
        XCTAssertTrue(path.contains("cursor=page2"))
    }

    // MARK: - Single Document Endpoint

    func test_document_withKey() {
        let path = APIEndpoints.document(key: "notes/meeting.md")
        XCTAssertEqual(path, "/documents/notes/meeting.md")
    }

    // MARK: - Search Endpoint

    func test_search_withQuery() {
        let path = APIEndpoints.search(query: "test")
        XCTAssertTrue(path.contains("/search?q=test"))
        XCTAssertTrue(path.contains("limit=20"))
    }

    func test_search_withCustomLimit() {
        let path = APIEndpoints.search(query: "test", limit: 5)
        XCTAssertTrue(path.contains("limit=5"))
    }

    // MARK: - Tags Endpoints

    func test_tags_endpoint() {
        XCTAssertEqual(APIEndpoints.tags, "/tags")
    }

    func test_documentsByTag() {
        let path = APIEndpoints.documentsByTag(tag: "swift")
        XCTAssertEqual(path, "/tags/swift/documents")
    }

    // MARK: - Insights Endpoints

    func test_summaries_endpoint() {
        XCTAssertEqual(APIEndpoints.summaries, "/summaries")
    }

    func test_reports_endpoint() {
        XCTAssertEqual(APIEndpoints.reports, "/reports")
    }

    // MARK: - Graph Endpoint

    func test_graph_endpoint() {
        XCTAssertEqual(APIEndpoints.graph, "/graph")
    }

    // MARK: - Search Monitor Endpoints

    func test_searchMonitors_endpoint() {
        XCTAssertEqual(APIEndpoints.searchMonitors, "/searches")
    }

    func test_searchMonitor_withId() {
        let path = APIEndpoints.searchMonitor(id: "mon-123")
        XCTAssertEqual(path, "/searches/mon-123")
    }

    func test_searchMonitor_withSpecialCharacters_encodesId() {
        let path = APIEndpoints.searchMonitor(id: "mon with spaces")
        XCTAssertTrue(path.contains("/searches/"))
        XCTAssertTrue(path.contains("mon%20with%20spaces"))
    }

    func test_searchMonitorSummaries_defaultLimit() {
        let path = APIEndpoints.searchMonitorSummaries(monitorId: "mon-1")
        XCTAssertTrue(path.contains("/searches/mon-1/summaries"))
        XCTAssertTrue(path.contains("limit=20"))
    }

    func test_searchMonitorSummaries_customLimit() {
        let path = APIEndpoints.searchMonitorSummaries(monitorId: "mon-1", limit: 50)
        XCTAssertTrue(path.contains("limit=50"))
    }

    func test_searchMonitorSummaries_encodesMonitorId() {
        let path = APIEndpoints.searchMonitorSummaries(monitorId: "mon special")
        XCTAssertFalse(path.contains("mon special"))
        XCTAssertTrue(path.contains("mon%20special"))
    }

    func test_searchMonitorSummary_withTimestamp() {
        let path = APIEndpoints.searchMonitorSummary(
            monitorId: "mon-1",
            timestamp: "2026-02-20T10:00:00Z"
        )
        XCTAssertTrue(path.contains("/searches/mon-1/summaries/"))
        XCTAssertTrue(path.contains("2026-02-20T10"))
    }

    func test_searchMonitorSummary_encodesTimestamp() {
        let path = APIEndpoints.searchMonitorSummary(
            monitorId: "mon-1",
            timestamp: "2026-02-20T10:00:00+05:00"
        )
        // Colons should be percent-encoded in path
        XCTAssertTrue(path.contains("/searches/mon-1/summaries/"))
        XCTAssertFalse(path.contains("10:00:00"))
        XCTAssertTrue(path.contains("10%3A00%3A00"))
    }
}
