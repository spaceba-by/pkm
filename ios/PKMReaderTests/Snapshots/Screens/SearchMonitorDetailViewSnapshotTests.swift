import SnapshotTesting
import SwiftUI
import XCTest
@testable import PKMReader

@MainActor
final class SearchMonitorDetailViewSnapshotTests: SnapshotTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var mock: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mock = MockAPIClient()
    }

    func test_loading() {
        // Don't set any result - view will show loading state
        let view = SearchMonitorDetailView(monitorId: "mon-1", apiClient: mock)
        assertDeviceSnapshot(of: view)
    }

    func test_loaded_activeMonitor() {
        let monitor = makeMonitor(status: .active)
        let summaries = [
            makeSummary(
                timestamp: "2026-02-20T10:00:00Z",
                summary: "Key findings in AI research today",
                noveltyScore: 0.85,
                significantUpdate: true,
                topics: ["AI", "research"]
            ),
            makeSummary(
                timestamp: "2026-02-19T10:00:00Z",
                summary: "Minor updates to existing frameworks",
                noveltyScore: 0.3,
                significantUpdate: false,
                topics: ["frameworks"]
            ),
        ]
        mock.getSearchMonitorResult = .success(SearchMonitorDetailResponse(
            monitor: monitor, summaries: summaries, summaryCount: 2
        ))

        let view = SearchMonitorDetailView(monitorId: "mon-1", apiClient: mock)
        assertDeviceSnapshotAfterTask(of: view)
    }

    func test_loaded_pausedMonitor_noSummaries() {
        let monitor = makeMonitor(status: .paused)
        mock.getSearchMonitorResult = .success(SearchMonitorDetailResponse(
            monitor: monitor, summaries: [], summaryCount: 0
        ))

        let view = SearchMonitorDetailView(monitorId: "mon-1", apiClient: mock)
        assertDeviceSnapshotAfterTask(of: view)
    }

    func test_error() {
        mock.getSearchMonitorResult = .failure(APIError.networkError)

        let view = SearchMonitorDetailView(monitorId: "mon-1", apiClient: mock)
        assertDeviceSnapshotAfterTask(of: view)
    }

    // MARK: - Helpers

    private func makeMonitor(status: SearchMonitorStatus) -> SearchMonitor {
        SearchMonitor(
            id: "mon-1",
            name: "AI Research Tracker",
            description: "Tracking latest developments in artificial intelligence",
            searchTerms: ["AI", "machine learning", "neural networks"],
            intervalHours: 12,
            noveltyThreshold: 0.5,
            status: status,
            lastExecuted: "2026-02-20T10:00:00Z",
            nextExecution: "2026-02-20T22:00:00Z",
            created: "2026-02-15T00:00:00Z",
            modified: "2026-02-20T10:00:00Z"
        )
    }

    private func makeSummary(
        timestamp: String,
        summary: String,
        noveltyScore: Double,
        significantUpdate: Bool,
        topics: [String]
    ) -> SearchSummary {
        SearchSummary(
            timestamp: timestamp,
            summary: summary,
            topics: topics,
            noveltyScore: noveltyScore,
            significantUpdate: significantUpdate,
            newItems: ["New paper published"],
            changedItems: ["Updated benchmark"],
            removedItems: [],
            analysis: "Detailed analysis of findings"
        )
    }
}
