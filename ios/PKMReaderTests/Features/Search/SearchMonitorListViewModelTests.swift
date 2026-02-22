import XCTest
@testable import PKMReader

@MainActor
final class SearchMonitorListViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: SearchMonitorListViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        mockAPIClient = MockAPIClient()
        sut = SearchMonitorListViewModel(apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
    }

    // MARK: - Load Monitors

    func test_loadMonitors_success_setsLoadedState() async {
        let monitors = [makeMonitor(id: "1"), makeMonitor(id: "2")]
        mockAPIClient.listSearchMonitorsResult = .success(monitors)

        await sut.loadMonitors()

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.monitors.count, 2)
        XCTAssertEqual(mockAPIClient.listSearchMonitorsCallCount, 1)
    }

    func test_loadMonitors_empty_setsEmptyState() async {
        mockAPIClient.listSearchMonitorsResult = .success([])

        await sut.loadMonitors()

        XCTAssertEqual(sut.state, .empty)
        XCTAssertTrue(sut.monitors.isEmpty)
    }

    func test_loadMonitors_error_setsErrorState() async {
        mockAPIClient.listSearchMonitorsResult = .failure(APIError.networkError)

        await sut.loadMonitors()

        if case .error = sut.state {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
    }

    // MARK: - Create Monitor

    func test_createMonitor_success_addsToList() async throws {
        let newMonitor = makeMonitor(id: "new-1", name: "New Monitor")
        mockAPIClient.createSearchMonitorResult = .success(newMonitor)

        // Start with loaded state
        mockAPIClient.listSearchMonitorsResult = .success([makeMonitor(id: "existing")])
        await sut.loadMonitors()

        let request = SearchMonitorRequest(name: "New Monitor", searchTerms: ["test"])
        let result = try await sut.createMonitor(request: request)

        XCTAssertEqual(result.id, "new-1")
        XCTAssertEqual(sut.monitors.count, 2)
        XCTAssertEqual(sut.monitors.first?.id, "new-1")
        XCTAssertEqual(mockAPIClient.createSearchMonitorCallCount, 1)
    }

    func test_createMonitor_error_throws() async {
        mockAPIClient.createSearchMonitorResult = .failure(APIError.networkError)

        let request = SearchMonitorRequest(name: "Test")
        do {
            _ = try await sut.createMonitor(request: request)
            XCTFail("Expected error")
        } catch {
            // Expected
        }
    }

    func test_createMonitor_setsLoadedState_whenEmpty() async throws {
        mockAPIClient.listSearchMonitorsResult = .success([])
        await sut.loadMonitors()
        XCTAssertEqual(sut.state, .empty)

        let newMonitor = makeMonitor(id: "new-1")
        mockAPIClient.createSearchMonitorResult = .success(newMonitor)

        let request = SearchMonitorRequest(name: "Test", searchTerms: ["test"])
        _ = try await sut.createMonitor(request: request)

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.monitors.count, 1)
    }

    func test_createMonitor_passesRequestToAPI() async throws {
        let newMonitor = makeMonitor(id: "new-1")
        mockAPIClient.createSearchMonitorResult = .success(newMonitor)

        let request = SearchMonitorRequest(
            name: "My Monitor",
            description: "A description",
            searchTerms: ["term1", "term2"],
            intervalHours: 12,
            noveltyThreshold: 0.5
        )
        _ = try await sut.createMonitor(request: request)

        XCTAssertEqual(mockAPIClient.lastCreateSearchMonitorRequest?.name, "My Monitor")
        XCTAssertEqual(mockAPIClient.lastCreateSearchMonitorRequest?.description, "A description")
        XCTAssertEqual(mockAPIClient.lastCreateSearchMonitorRequest?.searchTerms, ["term1", "term2"])
        XCTAssertEqual(mockAPIClient.lastCreateSearchMonitorRequest?.intervalHours, 12)
        XCTAssertEqual(mockAPIClient.lastCreateSearchMonitorRequest?.noveltyThreshold, 0.5)
    }

    // MARK: - Delete Monitor

    func test_deleteMonitor_success_removesFromList() async throws {
        let monitors = [makeMonitor(id: "1"), makeMonitor(id: "2")]
        mockAPIClient.listSearchMonitorsResult = .success(monitors)
        await sut.loadMonitors()

        try await sut.deleteMonitor(id: "1")

        XCTAssertEqual(sut.monitors.count, 1)
        XCTAssertEqual(sut.monitors.first?.id, "2")
        XCTAssertEqual(mockAPIClient.deleteSearchMonitorCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastDeleteSearchMonitorId, "1")
    }

    func test_deleteMonitor_lastItem_setsEmptyState() async throws {
        mockAPIClient.listSearchMonitorsResult = .success([makeMonitor(id: "only")])
        await sut.loadMonitors()

        try await sut.deleteMonitor(id: "only")

        XCTAssertEqual(sut.state, .empty)
        XCTAssertTrue(sut.monitors.isEmpty)
    }

    func test_deleteMonitor_error_throws() async {
        mockAPIClient.deleteSearchMonitorResult = .failure(APIError.networkError)
        mockAPIClient.listSearchMonitorsResult = .success([makeMonitor(id: "1")])
        await sut.loadMonitors()

        do {
            try await sut.deleteMonitor(id: "1")
            XCTFail("Expected error")
        } catch {
            // Expected - monitor should still be in list
            XCTAssertEqual(sut.monitors.count, 1)
        }
    }

    func test_deleteMonitor_nonExistentId_doesNotChangeList() async throws {
        mockAPIClient.listSearchMonitorsResult = .success([makeMonitor(id: "1")])
        await sut.loadMonitors()

        try await sut.deleteMonitor(id: "nonexistent")

        XCTAssertEqual(sut.monitors.count, 1)
        XCTAssertEqual(sut.monitors.first?.id, "1")
    }

    // MARK: - Refresh

    func test_refresh_updatesMonitors() async {
        mockAPIClient.listSearchMonitorsResult = .success([makeMonitor(id: "1")])
        await sut.loadMonitors()
        XCTAssertEqual(sut.monitors.count, 1)

        mockAPIClient.listSearchMonitorsResult = .success([makeMonitor(id: "1"), makeMonitor(id: "2")])
        await sut.refresh()

        XCTAssertEqual(sut.monitors.count, 2)
        XCTAssertEqual(mockAPIClient.listSearchMonitorsCallCount, 2)
    }

    func test_refresh_doesNotResetStateToLoading() async {
        mockAPIClient.listSearchMonitorsResult = .success([makeMonitor(id: "1")])
        await sut.loadMonitors()
        XCTAssertEqual(sut.state, .loaded)

        // Refresh should not set state to loading before fetching
        mockAPIClient.listSearchMonitorsResult = .success([makeMonitor(id: "1")])
        await sut.refresh()

        XCTAssertEqual(sut.state, .loaded)
    }

    // MARK: - Initial State

    func test_initialState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
        XCTAssertTrue(sut.monitors.isEmpty)
    }

    // MARK: - State Equality

    func test_state_loaded_equalsLoaded() {
        let state1 = SearchMonitorListViewModel.State.loaded
        let state2 = SearchMonitorListViewModel.State.loaded
        XCTAssertEqual(state1, state2)
    }

    func test_state_error_equalsError() {
        let state1 = SearchMonitorListViewModel.State.error(APIError.networkError)
        let state2 = SearchMonitorListViewModel.State.error(APIError.networkError)
        XCTAssertEqual(state1, state2)
    }

    func test_state_different_notEqual() {
        let state1 = SearchMonitorListViewModel.State.loading
        let state2 = SearchMonitorListViewModel.State.loaded
        XCTAssertNotEqual(state1, state2)
    }

    // MARK: - Helpers

    private func makeMonitor(id: String, name: String = "Test Monitor") -> SearchMonitor {
        SearchMonitor(
            id: id,
            name: name,
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
}
