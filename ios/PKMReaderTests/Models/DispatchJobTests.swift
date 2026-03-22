@testable import PKMReader
import XCTest

final class DispatchJobTests: XCTestCase {
    // MARK: - DispatchJob Computed Properties

    func test_id_returnsJobId() {
        let job = makeJob(id: "job-123")
        XCTAssertEqual(job.id, "job-123")
    }

    func test_isActive_trueForPending() {
        XCTAssertTrue(makeJob(status: "pending").isActive)
    }

    func test_isActive_trueForRunning() {
        XCTAssertTrue(makeJob(status: "running").isActive)
    }

    func test_isActive_falseForCompleted() {
        XCTAssertFalse(makeJob(status: "completed").isActive)
    }

    func test_isActive_falseForFailed() {
        XCTAssertFalse(makeJob(status: "failed").isActive)
    }

    func test_isComplete_trueForCompleted() {
        XCTAssertTrue(makeJob(status: "completed").isComplete)
    }

    func test_isComplete_falseForRunning() {
        XCTAssertFalse(makeJob(status: "running").isComplete)
    }

    func test_isFailed_trueForFailed() {
        XCTAssertTrue(makeJob(status: "failed").isFailed)
    }

    func test_isFailed_falseForCompleted() {
        XCTAssertFalse(makeJob(status: "completed").isFailed)
    }

    func test_statusIcon_pending() {
        XCTAssertEqual(makeJob(status: "pending").statusIcon, "clock")
    }

    func test_statusIcon_running() {
        XCTAssertEqual(makeJob(status: "running").statusIcon, "play.circle")
    }

    func test_statusIcon_completed() {
        XCTAssertEqual(makeJob(status: "completed").statusIcon, "checkmark.circle")
    }

    func test_statusIcon_failed() {
        XCTAssertEqual(makeJob(status: "failed").statusIcon, "xmark.circle")
    }

    func test_statusIcon_unknown() {
        XCTAssertEqual(makeJob(status: "unknown").statusIcon, "questionmark.circle")
    }

    func test_statusColor_pending() {
        XCTAssertEqual(makeJob(status: "pending").statusColor, "orange")
    }

    func test_statusColor_running() {
        XCTAssertEqual(makeJob(status: "running").statusColor, "blue")
    }

    func test_statusColor_completed() {
        XCTAssertEqual(makeJob(status: "completed").statusColor, "green")
    }

    func test_statusColor_failed() {
        XCTAssertEqual(makeJob(status: "failed").statusColor, "red")
    }

    func test_statusColor_unknown() {
        XCTAssertEqual(makeJob(status: "unknown").statusColor, "gray")
    }

    // MARK: - AgentType Computed Properties

    func test_agentType_id_returnsName() {
        let agentType = makeAgentType(name: "claude-code")
        XCTAssertEqual(agentType.id, "claude-code")
    }

    func test_agentType_isLocal_trueForLocal() {
        XCTAssertTrue(makeAgentType(target: "local").isLocal)
    }

    func test_agentType_isLocal_falseForECS() {
        XCTAssertFalse(makeAgentType(target: "ecs").isLocal)
    }

    func test_agentType_isECS_trueForECS() {
        XCTAssertTrue(makeAgentType(target: "ecs").isECS)
    }

    func test_agentType_isECS_falseForLocal() {
        XCTAssertFalse(makeAgentType(target: "local").isECS)
    }

    func test_agentType_targetIcon_local() {
        XCTAssertEqual(makeAgentType(target: "local").targetIcon, "desktopcomputer")
    }

    func test_agentType_targetIcon_ecs() {
        XCTAssertEqual(makeAgentType(target: "ecs").targetIcon, "cloud")
    }

    // MARK: - Helpers

    private func makeJob(
        id: String = "job-1",
        status: String = "pending"
    ) -> DispatchJob {
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

    private func makeAgentType(
        name: String = "test-agent",
        target: String = "local"
    ) -> AgentType {
        AgentType(
            name: name,
            target: target,
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
