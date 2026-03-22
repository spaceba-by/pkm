@testable import PKMReader
import XCTest

@MainActor
final class TaskListViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: TaskListViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        mockAPIClient = MockAPIClient()
        sut = TaskListViewModel(apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
    }

    // MARK: - Initial State

    func test_initialState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
        XCTAssertTrue(sut.tasks.isEmpty)
        XCTAssertNil(sut.stats)
        XCTAssertEqual(sut.selectedStatus, .open)
        XCTAssertFalse(sut.hasMorePages)
    }

    // MARK: - Load Tasks

    func test_loadTasks_success_setsLoadedState() async {
        let tasks = [makeTask(id: "t-1"), makeTask(id: "t-2")]
        mockAPIClient.listTasksResult = .success(
            TaskListResponse(tasks: tasks, count: 2, nextCursor: nil)
        )

        await sut.loadTasks()

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.tasks.count, 2)
        XCTAssertEqual(mockAPIClient.listTasksCallCount, 1)
    }

    func test_loadTasks_empty_setsLoadedState() async {
        mockAPIClient.listTasksResult = .success(
            TaskListResponse(tasks: [], count: 0, nextCursor: nil)
        )

        await sut.loadTasks()

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    func test_loadTasks_error_setsErrorState() async {
        mockAPIClient.listTasksResult = .failure(APIError.networkError)

        await sut.loadTasks()

        if case .error = sut.state {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
    }

    func test_loadTasks_passesSelectedStatus() async {
        sut.selectedStatus = .completed

        await sut.loadTasks()

        XCTAssertEqual(mockAPIClient.lastListTasksStatus, "completed")
    }

    // MARK: - Has More Pages

    func test_hasMorePages_trueWhenCursorExists() async {
        mockAPIClient.listTasksResult = .success(
            TaskListResponse(tasks: [makeTask()], count: 1, nextCursor: "next")
        )

        await sut.loadTasks()

        XCTAssertTrue(sut.hasMorePages)
    }

    func test_hasMorePages_falseWhenNoCursor() async {
        mockAPIClient.listTasksResult = .success(
            TaskListResponse(tasks: [], count: 0, nextCursor: nil)
        )

        await sut.loadTasks()

        XCTAssertFalse(sut.hasMorePages)
    }

    // MARK: - Load More Tasks

    func test_loadMoreTasks_appendsToList() async {
        let firstPage = [makeTask(id: "t-1")]
        let secondPage = [makeTask(id: "t-2")]
        mockAPIClient.listTasksResult = .success(
            TaskListResponse(tasks: firstPage, count: 1, nextCursor: "cursor-1")
        )
        await sut.loadTasks()

        mockAPIClient.listTasksResult = .success(
            TaskListResponse(tasks: secondPage, count: 1, nextCursor: nil)
        )
        await sut.loadMoreTasks()

        XCTAssertEqual(sut.tasks.count, 2)
        XCTAssertEqual(sut.tasks[0].taskId, "t-1")
        XCTAssertEqual(sut.tasks[1].taskId, "t-2")
    }

    func test_loadMoreTasks_noOp_whenNoCursor() async {
        mockAPIClient.listTasksResult = .success(
            TaskListResponse(tasks: [], count: 0, nextCursor: nil)
        )
        await sut.loadTasks()

        await sut.loadMoreTasks()

        XCTAssertEqual(mockAPIClient.listTasksCallCount, 1)
    }

    // MARK: - Load Stats

    func test_loadStats_success_setsStats() async {
        mockAPIClient.getTaskStatsResult = .success(
            TaskStatsResponse(open: 5, completed: 10, total: 15)
        )

        await sut.loadStats()

        XCTAssertEqual(sut.stats?.open, 5)
        XCTAssertEqual(sut.stats?.completed, 10)
        XCTAssertEqual(sut.stats?.total, 15)
        XCTAssertEqual(mockAPIClient.getTaskStatsCallCount, 1)
    }

    func test_loadStats_error_remainsNil() async {
        mockAPIClient.getTaskStatsResult = .failure(APIError.networkError)

        await sut.loadStats()

        XCTAssertNil(sut.stats)
    }

    // MARK: - Refresh

    func test_refresh_loadsBothTasksAndStats() async {
        mockAPIClient.getTaskStatsResult = .success(
            TaskStatsResponse(open: 3, completed: 7, total: 10)
        )

        await sut.refresh()

        XCTAssertEqual(mockAPIClient.listTasksCallCount, 1)
        XCTAssertEqual(mockAPIClient.getTaskStatsCallCount, 1)
    }

    // MARK: - Change Filter

    func test_changeFilter_updatesSelectedStatus() async {
        await sut.changeFilter(to: .completed)

        XCTAssertEqual(sut.selectedStatus, .completed)
    }

    func test_changeFilter_reloadsWithNewStatus() async {
        await sut.changeFilter(to: .all)

        XCTAssertEqual(mockAPIClient.listTasksCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastListTasksStatus, "all")
    }

    // MARK: - StatusFilter

    func test_statusFilter_displayName_capitalized() {
        XCTAssertEqual(TaskListViewModel.StatusFilter.open.displayName, "Open")
        XCTAssertEqual(TaskListViewModel.StatusFilter.completed.displayName, "Completed")
        XCTAssertEqual(TaskListViewModel.StatusFilter.all.displayName, "All")
    }

    // MARK: - Helpers

    private func makeTask(id: String = "t-1") -> ExtractedTask {
        ExtractedTask(
            taskId: id,
            description: "Test task",
            status: "open",
            documentPath: "docs/test.md"
        )
    }
}
