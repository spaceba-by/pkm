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

    // MARK: - Insight Viewed Endpoints

    func test_markSummaryViewed_path() {
        let path = APIEndpoints.markSummaryViewed(date: "2026-03-22")
        XCTAssertEqual(path, "/summaries/2026-03-22/viewed")
    }

    func test_markReportViewed_path() {
        let path = APIEndpoints.markReportViewed(week: "2026-W12")
        XCTAssertEqual(path, "/reports/2026-W12/viewed")
    }

    func test_markSearchSummaryViewed_path() {
        let path = APIEndpoints.markSearchSummaryViewed(monitorId: "m1", timestamp: "2026-01-01")
        XCTAssertEqual(path, "/searches/m1/summaries/2026-01-01/viewed")
    }

    func test_markSearchSummaryViewed_encodesSpecialCharacters() {
        let path = APIEndpoints.markSearchSummaryViewed(
            monitorId: "mon special",
            timestamp: "2026-01-01T10:00:00+05:00"
        )
        XCTAssertTrue(path.contains("mon%20special"))
        XCTAssertTrue(path.contains("10%3A00%3A00"))
    }

    func test_markAllViewed_path() {
        XCTAssertEqual(APIEndpoints.markAllViewed, "/insights/mark-all-viewed")
    }

    func test_unviewedCount_path() {
        XCTAssertEqual(APIEndpoints.unviewedCount, "/insights/unviewed-count")
    }

    // MARK: - Tasks Endpoints

    func test_tasks_defaultParameters() {
        let path = APIEndpoints.tasks()
        XCTAssertEqual(path, "/tasks?status=open&limit=50")
    }

    func test_tasks_withStatus() {
        let path = APIEndpoints.tasks(status: "completed")
        XCTAssertTrue(path.contains("status=completed"))
    }

    func test_tasks_withCustomLimit() {
        let path = APIEndpoints.tasks(limit: 10)
        XCTAssertTrue(path.contains("limit=10"))
    }

    func test_tasks_withCursor() {
        let path = APIEndpoints.tasks(cursor: "next-page")
        XCTAssertTrue(path.contains("cursor=next-page"))
    }

    func test_taskStats_path() {
        XCTAssertEqual(APIEndpoints.taskStats, "/tasks/stats")
    }

    // MARK: - Dispatch Job Endpoints

    func test_dispatchJobs_defaultParameters() {
        let path = APIEndpoints.dispatchJobs()
        XCTAssertEqual(path, "/dispatch/jobs?limit=50")
    }

    func test_dispatchJobs_withStatus() {
        let path = APIEndpoints.dispatchJobs(status: "running")
        XCTAssertTrue(path.contains("status=running"))
    }

    func test_dispatchJobs_withCursor() {
        let path = APIEndpoints.dispatchJobs(cursor: "abc")
        XCTAssertTrue(path.contains("cursor=abc"))
    }

    func test_dispatchJobs_withAllParameters() {
        let path = APIEndpoints.dispatchJobs(status: "pending", limit: 10, cursor: "next")
        XCTAssertTrue(path.contains("limit=10"))
        XCTAssertTrue(path.contains("status=pending"))
        XCTAssertTrue(path.contains("cursor=next"))
    }

    func test_dispatchJob_path() {
        let path = APIEndpoints.dispatchJob(jobId: "job-123")
        XCTAssertEqual(path, "/dispatch/jobs/job-123")
    }

    func test_agentTypes_path() {
        XCTAssertEqual(APIEndpoints.agentTypes, "/dispatch/agent-types")
    }
}
