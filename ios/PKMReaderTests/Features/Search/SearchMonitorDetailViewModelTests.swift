@testable import PKMReader
import XCTest

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

    func test_loadDetail_success_setsLoadedState() async {
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

    func test_loadDetail_error_setsErrorState() async {
        mockAPIClient.getSearchMonitorResult = .failure(APIError.networkError)

        await sut.loadDetail()

        if case .error = sut.state {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
        XCTAssertNil(sut.monitor)
    }

    func test_loadDetail_setsMonitorAndSummaries() async {
        let monitor = makeMonitor(id: "test-id", name: "My Monitor")
        let summaries = [
            makeSummary(timestamp: "2026-02-20T10:00:00Z"),
            makeSummary(timestamp: "2026-02-19T10:00:00Z"),
        ]
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: summaries, summaryCount: 2)
        )

        await sut.loadDetail()

        XCTAssertEqual(sut.monitor?.name, "My Monitor")
        XCTAssertEqual(sut.summaries.count, 2)
    }

    // MARK: - Toggle Pause/Resume

    func test_togglePauseResume_activeToPaused() async throws {
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
        XCTAssertEqual(mockAPIClient.lastUpdateSearchMonitorRequest?.status, .paused)
    }

    func test_togglePauseResume_pausedToActive() async throws {
        let monitor = makeMonitor(id: "test-id", status: .paused)
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: [], summaryCount: 0)
        )
        await sut.loadDetail()

        let activeMonitor = makeMonitor(id: "test-id", status: .active)
        mockAPIClient.updateSearchMonitorResult = .success(activeMonitor)

        try await sut.togglePauseResume()

        XCTAssertEqual(sut.monitor?.status, .active)
        XCTAssertEqual(mockAPIClient.lastUpdateSearchMonitorRequest?.status, .active)
    }

    func test_togglePauseResume_noMonitor_doesNothing() async throws {
        // No monitor loaded, togglePauseResume should return early
        try await sut.togglePauseResume()

        XCTAssertEqual(mockAPIClient.updateSearchMonitorCallCount, 0)
    }

    func test_togglePauseResume_error_throws() async {
        let monitor = makeMonitor(id: "test-id", status: .active)
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: [], summaryCount: 0)
        )
        await sut.loadDetail()

        mockAPIClient.updateSearchMonitorResult = .failure(APIError.networkError)

        do {
            try await sut.togglePauseResume()
            XCTFail("Expected error")
        } catch {
            // Expected - monitor should remain active
            XCTAssertEqual(sut.monitor?.status, .active)
        }
    }

    // MARK: - Update Monitor

    func test_updateMonitor_success_updatesMonitor() async throws {
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

    func test_updateMonitor_error_throws() async {
        let monitor = makeMonitor(id: "test-id")
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: [], summaryCount: 0)
        )
        await sut.loadDetail()

        mockAPIClient.updateSearchMonitorResult = .failure(APIError.networkError)

        let request = SearchMonitorRequest(name: "New Name")
        do {
            _ = try await sut.updateMonitor(request: request)
            XCTFail("Expected error")
        } catch {
            // Expected - monitor should remain unchanged
            XCTAssertEqual(sut.monitor?.name, "Test Monitor")
        }
    }

    // MARK: - Load More Summaries

    func test_loadMoreSummaries_success_appendsSummaries() async {
        let monitor = makeMonitor(id: "test-id")
        let initialSummaries = [makeSummary(timestamp: "2026-02-20T10:00:00Z")]
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: initialSummaries, summaryCount: 1)
        )
        await sut.loadDetail()
        XCTAssertEqual(sut.summaries.count, 1)

        let moreSummaries = [
            makeSummary(timestamp: "2026-02-19T10:00:00Z"),
            makeSummary(timestamp: "2026-02-18T10:00:00Z"),
        ]
        mockAPIClient.listSearchMonitorSummariesResult = .success(moreSummaries)

        await sut.loadMoreSummaries()

        XCTAssertEqual(sut.summaries.count, 3)
        XCTAssertEqual(mockAPIClient.listSearchMonitorSummariesCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastListSearchMonitorSummariesMonitorId, "test-id")
        XCTAssertEqual(mockAPIClient.lastListSearchMonitorSummariesLimit, 50)
    }

    func test_loadMoreSummaries_error_keepsPreviousSummaries() async {
        let monitor = makeMonitor(id: "test-id")
        let initialSummaries = [makeSummary(timestamp: "2026-02-20T10:00:00Z")]
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: initialSummaries, summaryCount: 1)
        )
        await sut.loadDetail()

        mockAPIClient.listSearchMonitorSummariesResult = .failure(APIError.networkError)

        await sut.loadMoreSummaries()

        XCTAssertEqual(sut.summaries.count, 1)
    }

    // MARK: - Refresh

    func test_refresh_reloadsData() async {
        let monitor = makeMonitor(id: "test-id")
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: [], summaryCount: 0)
        )

        await sut.loadDetail()
        await sut.refresh()

        XCTAssertEqual(mockAPIClient.getSearchMonitorCallCount, 2)
    }

    func test_refresh_updatesMonitorData() async {
        let monitor = makeMonitor(id: "test-id", name: "Original")
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: monitor, summaries: [], summaryCount: 0)
        )
        await sut.loadDetail()
        XCTAssertEqual(sut.monitor?.name, "Original")

        let updatedMonitor = makeMonitor(id: "test-id", name: "Updated")
        mockAPIClient.getSearchMonitorResult = .success(
            SearchMonitorDetailResponse(monitor: updatedMonitor, summaries: [], summaryCount: 0)
        )
        await sut.refresh()

        XCTAssertEqual(sut.monitor?.name, "Updated")
    }

    // MARK: - Initial State

    func test_initialState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
        XCTAssertNil(sut.monitor)
        XCTAssertTrue(sut.summaries.isEmpty)
    }

    func test_monitorId_isSet() {
        XCTAssertEqual(sut.monitorId, "test-id")
    }

    // MARK: - State Equality

    func test_state_loaded_equalsLoaded() {
        let state1 = SearchMonitorDetailViewModel.State.loaded
        let state2 = SearchMonitorDetailViewModel.State.loaded
        XCTAssertEqual(state1, state2)
    }

    func test_state_error_equalsError() {
        let state1 = SearchMonitorDetailViewModel.State.error(APIError.networkError)
        let state2 = SearchMonitorDetailViewModel.State.error(APIError.networkError)
        XCTAssertEqual(state1, state2)
    }

    func test_state_different_notEqual() {
        let state1 = SearchMonitorDetailViewModel.State.loading
        let state2 = SearchMonitorDetailViewModel.State.loaded
        XCTAssertNotEqual(state1, state2)
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
