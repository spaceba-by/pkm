@testable import PKMReader
import XCTest

@MainActor
final class WorkflowDetailViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: WorkflowDetailViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        mockAPIClient = MockAPIClient()
        sut = WorkflowDetailViewModel(workflow: makeWorkflow(id: "wf-1", name: "alpha"), apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
    }

    func test_loadRuns_setsRunsAndCursor() async {
        mockAPIClient.listWorkflowRunsResult = .success(
            WorkflowRunListResponse(runs: [makeRun(id: "r-1"), makeRun(id: "r-2")], count: 2, nextCursor: "next")
        )

        await sut.loadRuns()

        XCTAssertEqual(sut.runs.map(\.id), ["r-1", "r-2"])
        XCTAssertTrue(sut.hasMoreRuns)
        XCTAssertNil(mockAPIClient.lastListWorkflowRunsCursor)
        XCTAssertFalse(sut.isLoadingRuns)
    }

    func test_loadMoreRuns_appendsUsingCursor() async {
        mockAPIClient.listWorkflowRunsResult = .success(
            WorkflowRunListResponse(runs: [makeRun(id: "r-1")], count: 1, nextCursor: "next")
        )
        await sut.loadRuns()
        mockAPIClient.listWorkflowRunsResult = .success(
            WorkflowRunListResponse(runs: [makeRun(id: "r-2")], count: 1, nextCursor: nil)
        )

        await sut.loadMoreRuns()

        XCTAssertEqual(mockAPIClient.lastListWorkflowRunsCursor, "next")
        XCTAssertEqual(sut.runs.map(\.id), ["r-1", "r-2"])
        XCTAssertFalse(sut.hasMoreRuns)
    }

    func test_loadMoreRuns_withoutCursor_doesNothing() async {
        await sut.loadMoreRuns()
        XCTAssertEqual(mockAPIClient.listWorkflowRunsCallCount, 0)
    }

    func test_loadRuns_error_setsErrorMessage() async {
        mockAPIClient.listWorkflowRunsResult = .failure(APIError.networkError)

        await sut.loadRuns()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.runs.isEmpty)
    }

    func test_runNow_blankPath_sendsNilAndSetsStatus() async {
        let runId = await sut.runNow(documentPath: "   ")

        XCTAssertEqual(runId, "run-1")
        XCTAssertEqual(mockAPIClient.lastRunWorkflowId, "wf-1")
        XCTAssertNil(mockAPIClient.lastRunWorkflowDocumentPath)
        XCTAssertNotNil(sut.statusMessage)
        XCTAssertNil(sut.errorMessage)
    }

    func test_runNow_withPath_sendsTrimmedPath() async {
        await sut.runNow(documentPath: " meetings/a.md ")
        XCTAssertEqual(mockAPIClient.lastRunWorkflowDocumentPath, "meetings/a.md")
    }

    func test_runNow_failure_setsErrorMessage() async {
        mockAPIClient.runWorkflowResult = .failure(APIError.networkError)

        let runId = await sut.runNow(documentPath: nil)

        XCTAssertNil(runId)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertNil(sut.statusMessage)
    }

    func test_refresh_replacesWorkflowAndReloadsRuns() async {
        mockAPIClient.getWorkflowResult = .success(makeWorkflow(id: "wf-1", name: "alpha", enabled: false))

        await sut.refresh()

        XCTAssertEqual(sut.workflow.enabled, false)
        XCTAssertEqual(mockAPIClient.getWorkflowCallCount, 1)
        XCTAssertEqual(mockAPIClient.listWorkflowRunsCallCount, 1)
    }

    func test_apply_replacesWorkflow() {
        sut.apply(makeWorkflow(id: "wf-1", name: "renamed"))
        XCTAssertEqual(sut.workflow.name, "renamed")
    }
}
