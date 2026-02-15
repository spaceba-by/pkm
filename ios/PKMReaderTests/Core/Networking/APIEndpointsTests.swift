import XCTest
@testable import PKMReader

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
}
