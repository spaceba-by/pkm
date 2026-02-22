import XCTest
@testable import PKMReader

final class SearchMonitorModelTests: XCTestCase {
    // MARK: - SearchMonitorStatus

    func test_status_active_rawValue() {
        XCTAssertEqual(SearchMonitorStatus.active.rawValue, "active")
    }

    func test_status_paused_rawValue() {
        XCTAssertEqual(SearchMonitorStatus.paused.rawValue, "paused")
    }

    func test_status_decodesFromJSON() throws {
        let json = Data("""
        "active"
        """.utf8)
        let status = try JSONDecoder().decode(SearchMonitorStatus.self, from: json)
        XCTAssertEqual(status, .active)
    }

    func test_status_encodesAndDecodes() throws {
        let status = SearchMonitorStatus.paused
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(SearchMonitorStatus.self, from: data)
        XCTAssertEqual(decoded, status)
    }

    // MARK: - SearchMonitor

    func test_monitor_identifiable() {
        let monitor = makeMonitor(id: "test-123")
        XCTAssertEqual(monitor.id, "test-123")
    }

    func test_monitor_hashable() {
        let monitor1 = makeMonitor(id: "test-1")
        let monitor2 = makeMonitor(id: "test-1")
        XCTAssertEqual(monitor1, monitor2)
    }

    func test_monitor_hashable_differentIds_notEqual() {
        let monitor1 = makeMonitor(id: "test-1")
        let monitor2 = makeMonitor(id: "test-2")
        XCTAssertNotEqual(monitor1, monitor2)
    }

    func test_monitor_decodesFromJSON() throws {
        let json = Data("""
        {
            "id": "mon-1",
            "name": "Tech News",
            "description": "Track tech updates",
            "searchTerms": ["AI", "ML"],
            "intervalHours": 12,
            "noveltyThreshold": 0.5,
            "status": "active",
            "lastExecuted": "2026-02-20T10:00:00Z",
            "nextExecution": "2026-02-20T22:00:00Z",
            "created": "2026-02-19T00:00:00Z",
            "modified": "2026-02-20T10:00:00Z"
        }
        """.utf8)

        let monitor = try JSONDecoder().decode(SearchMonitor.self, from: json)
        XCTAssertEqual(monitor.id, "mon-1")
        XCTAssertEqual(monitor.name, "Tech News")
        XCTAssertEqual(monitor.description, "Track tech updates")
        XCTAssertEqual(monitor.searchTerms, ["AI", "ML"])
        XCTAssertEqual(monitor.intervalHours, 12)
        XCTAssertEqual(monitor.noveltyThreshold, 0.5)
        XCTAssertEqual(monitor.status, .active)
        XCTAssertEqual(monitor.lastExecuted, "2026-02-20T10:00:00Z")
        XCTAssertEqual(monitor.nextExecution, "2026-02-20T22:00:00Z")
    }

    func test_monitor_decodesFromJSON_nullLastExecuted() throws {
        let json = Data("""
        {
            "id": "mon-1",
            "name": "New Monitor",
            "description": "",
            "searchTerms": ["test"],
            "intervalHours": 6,
            "noveltyThreshold": 0.3,
            "status": "paused",
            "lastExecuted": null,
            "nextExecution": "2026-02-21T00:00:00Z",
            "created": "2026-02-20T00:00:00Z",
            "modified": "2026-02-20T00:00:00Z"
        }
        """.utf8)

        let monitor = try JSONDecoder().decode(SearchMonitor.self, from: json)
        XCTAssertNil(monitor.lastExecuted)
        XCTAssertEqual(monitor.status, .paused)
    }

    func test_monitor_encodesAndDecodes() throws {
        let monitor = makeMonitor(id: "roundtrip")
        let data = try JSONEncoder().encode(monitor)
        let decoded = try JSONDecoder().decode(SearchMonitor.self, from: data)
        XCTAssertEqual(decoded, monitor)
    }

    // MARK: - SearchSummary

    func test_summary_identifiable_usesTimestamp() {
        let summary = makeSummary(timestamp: "2026-02-20T10:00:00Z")
        XCTAssertEqual(summary.id, "2026-02-20T10:00:00Z")
    }

    func test_summary_hashable() {
        let summary1 = makeSummary(timestamp: "2026-02-20T10:00:00Z")
        let summary2 = makeSummary(timestamp: "2026-02-20T10:00:00Z")
        XCTAssertEqual(summary1, summary2)
    }

    func test_summary_decodesFromJSON() throws {
        let json = Data("""
        {
            "timestamp": "2026-02-20T10:00:00Z",
            "summary": "Key findings in AI research",
            "topics": ["AI", "research"],
            "noveltyScore": 0.75,
            "significantUpdate": true,
            "newItems": ["New paper on LLMs"],
            "changedItems": ["Updated benchmark results"],
            "removedItems": ["Deprecated framework"],
            "analysis": "Detailed analysis here"
        }
        """.utf8)

        let summary = try JSONDecoder().decode(SearchSummary.self, from: json)
        XCTAssertEqual(summary.timestamp, "2026-02-20T10:00:00Z")
        XCTAssertEqual(summary.summary, "Key findings in AI research")
        XCTAssertEqual(summary.topics, ["AI", "research"])
        XCTAssertEqual(summary.noveltyScore, 0.75)
        XCTAssertTrue(summary.significantUpdate)
        XCTAssertEqual(summary.newItems, ["New paper on LLMs"])
        XCTAssertEqual(summary.changedItems, ["Updated benchmark results"])
        XCTAssertEqual(summary.removedItems, ["Deprecated framework"])
        XCTAssertEqual(summary.analysis, "Detailed analysis here")
    }

    func test_summary_decodesFromJSON_nullAnalysis() throws {
        let json = Data("""
        {
            "timestamp": "2026-02-20T10:00:00Z",
            "summary": "Summary text",
            "topics": [],
            "noveltyScore": 0.1,
            "significantUpdate": false,
            "newItems": [],
            "changedItems": [],
            "removedItems": [],
            "analysis": null
        }
        """.utf8)

        let summary = try JSONDecoder().decode(SearchSummary.self, from: json)
        XCTAssertNil(summary.analysis)
        XCTAssertFalse(summary.significantUpdate)
        XCTAssertTrue(summary.topics.isEmpty)
    }

    func test_summary_encodesAndDecodes() throws {
        let summary = makeSummary(timestamp: "2026-02-20T10:00:00Z")
        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(SearchSummary.self, from: data)
        XCTAssertEqual(decoded, summary)
    }

    // MARK: - Response Wrappers

    func test_listResponse_decodesFromJSON() throws {
        let json = Data("""
        {
            "monitors": [{
                "id": "mon-1",
                "name": "Test",
                "description": "",
                "searchTerms": ["test"],
                "intervalHours": 6,
                "noveltyThreshold": 0.3,
                "status": "active",
                "lastExecuted": null,
                "nextExecution": "2026-02-21T00:00:00Z",
                "created": "2026-02-20T00:00:00Z",
                "modified": "2026-02-20T00:00:00Z"
            }],
            "count": 1
        }
        """.utf8)

        let response = try JSONDecoder().decode(SearchMonitorListResponse.self, from: json)
        XCTAssertEqual(response.monitors.count, 1)
        XCTAssertEqual(response.count, 1)
        XCTAssertEqual(response.monitors.first?.id, "mon-1")
    }

    func test_detailResponse_decodesFromJSON() throws {
        let json = Data("""
        {
            "monitor": {
                "id": "mon-1",
                "name": "Test",
                "description": "",
                "searchTerms": ["test"],
                "intervalHours": 6,
                "noveltyThreshold": 0.3,
                "status": "active",
                "lastExecuted": null,
                "nextExecution": "2026-02-21T00:00:00Z",
                "created": "2026-02-20T00:00:00Z",
                "modified": "2026-02-20T00:00:00Z"
            },
            "summaries": [],
            "summaryCount": 0
        }
        """.utf8)

        let response = try JSONDecoder().decode(SearchMonitorDetailResponse.self, from: json)
        XCTAssertEqual(response.monitor.id, "mon-1")
        XCTAssertTrue(response.summaries.isEmpty)
        XCTAssertEqual(response.summaryCount, 0)
    }

    func test_summaryListResponse_decodesFromJSON() throws {
        let json = Data("""
        {
            "summaries": [{
                "timestamp": "2026-02-20T10:00:00Z",
                "summary": "Test",
                "topics": [],
                "noveltyScore": 0.5,
                "significantUpdate": false,
                "newItems": [],
                "changedItems": [],
                "removedItems": [],
                "analysis": null
            }],
            "count": 1,
            "monitorId": "mon-1"
        }
        """.utf8)

        let response = try JSONDecoder().decode(SearchSummaryListResponse.self, from: json)
        XCTAssertEqual(response.summaries.count, 1)
        XCTAssertEqual(response.count, 1)
        XCTAssertEqual(response.monitorId, "mon-1")
    }

    // MARK: - SearchMonitorRequest

    func test_request_encodesAllFields() throws {
        let request = SearchMonitorRequest(
            name: "My Monitor",
            description: "Desc",
            searchTerms: ["a", "b"],
            intervalHours: 12,
            noveltyThreshold: 0.5,
            status: .active
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(SearchMonitorRequest.self, from: data)
        XCTAssertEqual(decoded.name, "My Monitor")
        XCTAssertEqual(decoded.description, "Desc")
        XCTAssertEqual(decoded.searchTerms, ["a", "b"])
        XCTAssertEqual(decoded.intervalHours, 12)
        XCTAssertEqual(decoded.noveltyThreshold, 0.5)
        XCTAssertEqual(decoded.status, .active)
    }

    func test_request_encodesPartialFields() throws {
        let request = SearchMonitorRequest(name: "Partial")

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(SearchMonitorRequest.self, from: data)
        XCTAssertEqual(decoded.name, "Partial")
        XCTAssertNil(decoded.description)
        XCTAssertNil(decoded.searchTerms)
        XCTAssertNil(decoded.intervalHours)
        XCTAssertNil(decoded.noveltyThreshold)
        XCTAssertNil(decoded.status)
    }

    func test_request_statusOnly() throws {
        let request = SearchMonitorRequest(status: .paused)

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(SearchMonitorRequest.self, from: data)
        XCTAssertNil(decoded.name)
        XCTAssertEqual(decoded.status, .paused)
    }

    // MARK: - Helpers

    private func makeMonitor(id: String) -> SearchMonitor {
        SearchMonitor(
            id: id,
            name: "Test",
            description: "",
            searchTerms: ["test"],
            intervalHours: 6,
            noveltyThreshold: 0.3,
            status: .active,
            lastExecuted: nil,
            nextExecution: "2026-02-21T00:00:00Z",
            created: "2026-02-20T00:00:00Z",
            modified: "2026-02-20T00:00:00Z"
        )
    }

    private func makeSummary(timestamp: String) -> SearchSummary {
        SearchSummary(
            timestamp: timestamp,
            summary: "Test summary",
            topics: ["test"],
            noveltyScore: 0.5,
            significantUpdate: false,
            newItems: [],
            changedItems: [],
            removedItems: [],
            analysis: nil
        )
    }
}
