@testable import PKMReader
import XCTest

@MainActor
final class DispatchListViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: DispatchListViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        mockAPIClient = MockAPIClient()
        sut = DispatchListViewModel(apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
    }

    // MARK: - Initial State

    func test_initialState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
        XCTAssertTrue(sut.jobs.isEmpty)
        XCTAssertEqual(sut.selectedStatus, .all)
    }

    // MARK: - Load Jobs

    func test_loadJobs_success_setsLoadedState() async {
        let jobs = [makeJob(id: "job-1"), makeJob(id: "job-2")]
        mockAPIClient.listJobsResult = .success(
            JobListResponse(jobs: jobs, count: 2, nextCursor: nil)
        )

        await sut.loadJobs()

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.jobs.count, 2)
        XCTAssertEqual(mockAPIClient.listJobsCallCount, 1)
    }

    func test_loadJobs_empty_setsLoadedState() async {
        mockAPIClient.listJobsResult = .success(
            JobListResponse(jobs: [], count: 0, nextCursor: nil)
        )

        await sut.loadJobs()

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertTrue(sut.jobs.isEmpty)
    }

    func test_loadJobs_error_setsErrorState() async {
        mockAPIClient.listJobsResult = .failure(APIError.networkError)

        await sut.loadJobs()

        if case .error = sut.state {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
    }

    func test_loadJobs_allFilter_passesNilStatus() async {
        sut.selectedStatus = .all

        await sut.loadJobs()

        XCTAssertNil(mockAPIClient.lastListJobsStatus)
    }

    func test_loadJobs_pendingFilter_passesStatus() async {
        sut.selectedStatus = .pending

        await sut.loadJobs()

        XCTAssertEqual(mockAPIClient.lastListJobsStatus, "pending")
    }

    // MARK: - Load More Jobs

    func test_loadMoreJobs_appendsToList() async {
        let firstPage = [makeJob(id: "job-1")]
        let secondPage = [makeJob(id: "job-2")]
        mockAPIClient.listJobsResult = .success(
            JobListResponse(jobs: firstPage, count: 1, nextCursor: "cursor-1")
        )
        await sut.loadJobs()

        mockAPIClient.listJobsResult = .success(
            JobListResponse(jobs: secondPage, count: 1, nextCursor: nil)
        )
        await sut.loadMoreJobs()

        XCTAssertEqual(sut.jobs.count, 2)
        XCTAssertEqual(sut.jobs[0].jobId, "job-1")
        XCTAssertEqual(sut.jobs[1].jobId, "job-2")
    }

    func test_loadMoreJobs_noOp_whenNoCursor() async {
        mockAPIClient.listJobsResult = .success(
            JobListResponse(jobs: [], count: 0, nextCursor: nil)
        )
        await sut.loadJobs()

        await sut.loadMoreJobs()

        XCTAssertEqual(mockAPIClient.listJobsCallCount, 1)
    }

    // MARK: - Change Filter

    func test_changeFilter_updatesSelectedStatus() async {
        await sut.changeFilter(to: .running)

        XCTAssertEqual(sut.selectedStatus, .running)
    }

    func test_changeFilter_reloadsJobs() async {
        await sut.changeFilter(to: .completed)

        XCTAssertEqual(mockAPIClient.listJobsCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastListJobsStatus, "completed")
    }

    // MARK: - Load Agent Types

    func test_loadAgentTypes_success_setsTypes() async {
        mockAPIClient.listAgentTypesResult = .success([
            makeAgentType(name: "claude-code"),
        ])

        await sut.loadAgentTypes()

        XCTAssertEqual(sut.agentTypes.count, 1)
        XCTAssertEqual(sut.agentTypes[0].name, "claude-code")
    }

    func test_loadAgentTypes_error_remainsEmpty() async {
        mockAPIClient.listAgentTypesResult = .failure(APIError.networkError)

        await sut.loadAgentTypes()

        XCTAssertTrue(sut.agentTypes.isEmpty)
    }

    // MARK: - Create Job

    func test_createJob_returnsResponse() async throws {
        let response = try await sut.createJob(
            taskDescription: "Build feature",
            agentType: "claude-code",
            contextPaths: nil
        )

        XCTAssertEqual(response.jobId, "test-job-id")
        XCTAssertEqual(mockAPIClient.createJobCallCount, 1)
    }

    func test_createJob_reloadsJobsAfter() async throws {
        _ = try await sut.createJob(
            taskDescription: "Build feature",
            agentType: "claude-code",
            contextPaths: nil
        )

        // createJob calls loadJobs internally
        XCTAssertEqual(mockAPIClient.listJobsCallCount, 1)
    }

    // MARK: - StatusFilter

    func test_statusFilter_displayName_capitalized() {
        XCTAssertEqual(DispatchListViewModel.StatusFilter.all.displayName, "All")
        XCTAssertEqual(DispatchListViewModel.StatusFilter.pending.displayName, "Pending")
        XCTAssertEqual(DispatchListViewModel.StatusFilter.running.displayName, "Running")
        XCTAssertEqual(DispatchListViewModel.StatusFilter.completed.displayName, "Completed")
        XCTAssertEqual(DispatchListViewModel.StatusFilter.failed.displayName, "Failed")
    }

    // MARK: - Helpers

    private func makeJob(id: String = "job-1", status: String = "pending") -> DispatchJob {
        DispatchJob(
            jobId: id,
            status: status,
            agentType: "claude-code",
            taskDescription: "Test task",
            contextPaths: nil,
            created: Date(),
            updated: Date(),
            startedAt: nil,
            completedAt: nil,
            error: nil,
            artifacts: nil,
            resultPath: nil,
            ecsTaskArn: nil,
            claimedBy: nil,
            createdBy: nil
        )
    }

    private func makeAgentType(name: String = "test-agent") -> AgentType {
        AgentType(
            name: name,
            target: "local",
            description: "Test agent",
            created: Date(),
            updated: Date(),
            ecsTaskDefinition: nil,
            ecsCluster: nil,
            ecsSubnets: nil,
            ecsSecurityGroups: nil,
            containerImage: nil,
            containerName: nil,
            cpu: nil,
            memory: nil
        )
    }
}
