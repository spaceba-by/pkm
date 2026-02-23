@testable import PKMReader
import SnapshotTesting
import SwiftUI
import XCTest

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
}
