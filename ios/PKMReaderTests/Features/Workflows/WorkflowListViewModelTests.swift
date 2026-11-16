@testable import PKMReader
import XCTest

@MainActor
final class WorkflowListViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: WorkflowListViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        mockAPIClient = MockAPIClient()
        sut = WorkflowListViewModel(apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
    }

    func test_initialState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
        XCTAssertTrue(sut.workflows.isEmpty)
    }

    func test_loadWorkflows_success_sortsByName() async {
        mockAPIClient.listWorkflowsResult = .success([
            makeWorkflow(id: "b", name: "zeta"),
            makeWorkflow(id: "a", name: "alpha"),
        ])

        await sut.loadWorkflows()

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.workflows.map(\.name), ["alpha", "zeta"])
        XCTAssertEqual(mockAPIClient.listWorkflowsCallCount, 1)
    }

    func test_loadWorkflows_error_setsErrorState() async {
        mockAPIClient.listWorkflowsResult = .failure(APIError.networkError)

        await sut.loadWorkflows()

        guard case .error = sut.state else {
            return XCTFail("Expected error state, got \(sut.state)")
        }
    }

    func test_createWorkflow_appendsAndSorts() async throws {
        mockAPIClient.listWorkflowsResult = .success([makeWorkflow(id: "m", name: "middle")])
        await sut.loadWorkflows()
        mockAPIClient.createWorkflowResult = .success(makeWorkflow(id: "a", name: "alpha"))

        let created = try await sut.createWorkflow(WorkflowRequest(name: "alpha"))

        XCTAssertEqual(created.id, "a")
        XCTAssertEqual(sut.workflows.map(\.name), ["alpha", "middle"])
        XCTAssertEqual(mockAPIClient.lastCreateWorkflowRequest?.name, "alpha")
    }

    func test_setEnabled_sendsOnlyEnabledFlagAndReplaces() async {
        let workflow = makeWorkflow(id: "a", name: "alpha", enabled: true)
        mockAPIClient.listWorkflowsResult = .success([workflow])
        await sut.loadWorkflows()
        mockAPIClient.updateWorkflowResult = .success(makeWorkflow(id: "a", name: "alpha", enabled: false))

        await sut.setEnabled(workflow, enabled: false)

        XCTAssertEqual(mockAPIClient.updateWorkflowCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastUpdateWorkflowId, "a")
        XCTAssertEqual(mockAPIClient.lastUpdateWorkflowRequest, WorkflowRequest(enabled: false))
        XCTAssertEqual(sut.workflows.first?.enabled, false)
        XCTAssertNil(sut.actionError)
    }

    func test_setEnabled_noChange_doesNotCallAPI() async {
        let workflow = makeWorkflow(id: "a", name: "alpha", enabled: true)

        await sut.setEnabled(workflow, enabled: true)

        XCTAssertEqual(mockAPIClient.updateWorkflowCallCount, 0)
    }

    func test_setEnabled_failure_setsActionErrorAndKeepsState() async {
        let workflow = makeWorkflow(id: "a", name: "alpha", enabled: true)
        mockAPIClient.listWorkflowsResult = .success([workflow])
        await sut.loadWorkflows()
        mockAPIClient.updateWorkflowResult = .failure(APIError.networkError)

        await sut.setEnabled(workflow, enabled: false)

        XCTAssertNotNil(sut.actionError)
        XCTAssertEqual(sut.workflows.first?.enabled, true)
    }

    func test_deleteWorkflow_success_removes() async {
        let workflow = makeWorkflow(id: "a", name: "alpha")
        mockAPIClient.listWorkflowsResult = .success([workflow, makeWorkflow(id: "b", name: "beta")])
        await sut.loadWorkflows()

        await sut.deleteWorkflow(workflow)

        XCTAssertEqual(mockAPIClient.lastDeleteWorkflowId, "a")
        XCTAssertEqual(sut.workflows.map(\.id), ["b"])
    }

    func test_deleteWorkflow_failure_setsActionErrorAndKeepsItem() async {
        let workflow = makeWorkflow(id: "a", name: "alpha")
        mockAPIClient.listWorkflowsResult = .success([workflow])
        await sut.loadWorkflows()
        mockAPIClient.deleteWorkflowResult = .failure(APIError.networkError)

        await sut.deleteWorkflow(workflow)

        XCTAssertNotNil(sut.actionError)
        XCTAssertEqual(sut.workflows.count, 1)
    }
}
