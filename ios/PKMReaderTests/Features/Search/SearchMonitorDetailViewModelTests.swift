import XCTest
@testable import PKMReader

@MainActor
final class SearchMonitorDetailViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: SearchMonitorDetailViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        mockAPIClient = MockAPIClient()
        sut = SearchMonitorDetailViewModel(monitorId: "test-id", apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
    }

    // MARK: - Load Detail

    func testLoadDetail_success_setsLoadedState() async {
        let monitor = makeMonitor(id: "test-id")
        let summaries = [makeSummary(timestamp: "2026-02-20T10:00:00Z")]
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: summaries, summaryCount: 1)
        )

        await sut.loadDetail()

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.monitor?.id, "test-id")
        XCTAssertEqual(sut.summaries.count, 1)
        XCTAssertEqual(mockAPIClient.getSearchMonitorCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastGetSearchMonitorId, "test-id")
    }

    func testLoadDetail_error_setsErrorState() async {
        mockAPIClient.getSearchMonitorResult = .failure(APIError.networkError)

        await sut.loadDetail()

        if case .error = sut.state {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
        XCTAssertNil(sut.monitor)
    }

    // MARK: - Toggle Pause/Resume

    func testTogglePauseResume_activeTopaused() async throws {
        let monitor = makeMonitor(id: "test-id", status: .active)
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: [], summaryCount: 0)
        )
        await sut.loadDetail()

        let pausedMonitor = makeMonitor(id: "test-id", status: .paused)
        mockAPIClient.updateSearchMonitorResult = .success(pausedMonitor)

        try await sut.togglePauseResume()

        XCTAssertEqual(sut.monitor?.status, .paused)
        XCTAssertEqual(mockAPIClient.updateSearchMonitorCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastUpdateSearchMonitorRequest?.status, "paused")
    }

    func testTogglePauseResume_pausedToActive() async throws {
        let monitor = makeMonitor(id: "test-id", status: .paused)
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: [], summaryCount: 0)
        )
        await sut.loadDetail()

        let activeMonitor = makeMonitor(id: "test-id", status: .active)
        mockAPIClient.updateSearchMonitorResult = .success(activeMonitor)

        try await sut.togglePauseResume()

        XCTAssertEqual(sut.monitor?.status, .active)
        XCTAssertEqual(mockAPIClient.lastUpdateSearchMonitorRequest?.status, "active")
    }

    // MARK: - Update Monitor

    func testUpdateMonitor_success_updatesMonitor() async throws {
        let monitor = makeMonitor(id: "test-id", name: "Old Name")
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: [], summaryCount: 0)
        )
        await sut.loadDetail()

        let updated = makeMonitor(id: "test-id", name: "New Name")
        mockAPIClient.updateSearchMonitorResult = .success(updated)

        let request = SearchMonitorRequest(name: "New Name")
        let result = try await sut.updateMonitor(request: request)

        XCTAssertEqual(result.name, "New Name")
        XCTAssertEqual(sut.monitor?.name, "New Name")
        XCTAssertEqual(mockAPIClient.updateSearchMonitorCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastUpdateSearchMonitorId, "test-id")
    }

    // MARK: - Load More Summaries

    func testLoadMoreSummaries_success_updatesSummaries() async {
        let monitor = makeMonitor(id: "test-id")
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: [], summaryCount: 0)
        )
        await sut.loadDetail()

        let moreSummaries = [
            makeSummary(timestamp: "2026-02-20T10:00:00Z"),
            makeSummary(timestamp: "2026-02-19T10:00:00Z")
        ]
        mockAPIClient.listSearchMonitorSummariesResult = .success(moreSummaries)

        await sut.loadMoreSummaries()

        XCTAssertEqual(sut.summaries.count, 2)
        XCTAssertEqual(mockAPIClient.listSearchMonitorSummariesCallCount, 1)
    }

    // MARK: - Refresh

    func testRefresh_reloadsData() async {
        let monitor = makeMonitor(id: "test-id")
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: [], summaryCount: 0)
        )

        await sut.loadDetail()
        await sut.refresh()

        XCTAssertEqual(mockAPIClient.getSearchMonitorCallCount, 2)
    }

    // MARK: - Helpers

    private func makeMonitor(
        id: String,
        name: String = "Test Monitor",
        status: SearchMonitorStatus = .active
    ) -> SearchMonitor {
        SearchMonitor(
            id: id,
            name: name,
            description: "",
            searchTerms: ["test"],
            intervalHours: 6,
            noveltyThreshold: 0.3,
            status: status,
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
