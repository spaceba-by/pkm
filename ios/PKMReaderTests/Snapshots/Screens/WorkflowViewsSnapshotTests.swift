@testable import PKMReader
import SnapshotTesting
import SwiftUI
import XCTest

final class WorkflowViewsSnapshotTests: SnapshotTestCase {
    // MARK: - Fixtures

    private var documentWorkflow: Workflow {
        Workflow(
            id: "wf-doc",
            name: "action-items",
            description: "Extract action items from meeting notes",
            enabled: true,
            trigger: WorkflowTrigger(type: .document, schedule: nil),
            filter: WorkflowFilter(
                pathPrefix: "meetings/",
                tags: ["work"],
                classifications: ["meeting"],
                lookbackDays: nil
            ),
            prompt: WorkflowPrompt(
                system: "You extract action items.",
                user: "Extract action items from {{document.title}}:\n{{document.body}}",
                model: .haiku,
                maxTokens: 2000,
                temperature: 0.2
            ),
            output: WorkflowOutput(destination: .s3, path: "_agent/actions/{{document.title}}.md"),
            cooldownMinutes: 60,
            runCount: 12,
            created: "2026-01-01T00:00:00Z",
            updated: "2026-01-10T00:00:00Z",
            nextRun: nil,
            lastRun: "2026-01-10T09:00:00Z",
            lastStatus: "completed",
            createdBy: "user-1",
            recentRuns: nil
        )
    }

    private var scheduleWorkflow: Workflow {
        Workflow(
            id: "wf-sched",
            name: "weekly-digest",
            description: "",
            enabled: false,
            trigger: WorkflowTrigger(
                type: .schedule,
                schedule: WorkflowSchedule(frequency: .weekly, minute: 0, hour: 6, dayOfWeek: "monday")
            ),
            filter: WorkflowFilter(pathPrefix: nil, tags: ["project-x"], classifications: nil, lookbackDays: 7),
            prompt: WorkflowPrompt(
                system: nil,
                user: "Summarize {{documents.count}} documents:\n{{documents.content}}",
                model: .sonnet,
                maxTokens: 4096,
                temperature: 0.7
            ),
            output: WorkflowOutput(destination: .notification, path: nil),
            cooldownMinutes: 60,
            runCount: 0,
            created: nil,
            updated: nil,
            nextRun: "2026-01-12T06:00:00Z",
            lastRun: nil,
            lastStatus: nil,
            createdBy: nil,
            recentRuns: nil
        )
    }

    private var completedRun: WorkflowRun {
        WorkflowRun(
            runId: "run-1",
            workflowId: "wf-doc",
            workflowName: "action-items",
            trigger: "document",
            status: "completed",
            started: "2026-01-10T09:00:00Z",
            documentPath: "meetings/2026-01-10 Planning.md",
            documentCount: nil,
            completed: "2026-01-10T09:00:04Z",
            durationMs: 4200,
            modelId: "anthropic.claude-haiku",
            inputTokens: 1840,
            outputTokens: 212,
            outputS3Key: "_agent/actions/2026-01-10 Planning.md",
            result: "- [ ] Alice: send the revised budget by Friday\n- [ ] Bob: book the offsite venue",
            error: nil
        )
    }

    private var failedRun: WorkflowRun {
        WorkflowRun(
            runId: "run-2",
            workflowId: "wf-doc",
            workflowName: "action-items",
            trigger: "manual",
            status: "failed",
            started: "2026-01-09T15:30:00Z",
            documentPath: "meetings/missing.md",
            documentCount: nil,
            completed: "2026-01-09T15:30:01Z",
            durationMs: 300,
            modelId: nil,
            inputTokens: nil,
            outputTokens: nil,
            outputS3Key: nil,
            result: nil,
            error: "Document not readable: meetings/missing.md"
        )
    }

    private func mockClient() -> MockAPIClient {
        let mock = MockAPIClient()
        mock.listWorkflowsResult = .success([scheduleWorkflow, documentWorkflow])
        mock.listWorkflowRunsResult = .success(
            WorkflowRunListResponse(runs: [completedRun, failedRun], count: 2, nextCursor: "more")
        )
        return mock
    }

    // MARK: - List

    func test_list_loaded() {
        assertDeviceSnapshotAfterTask(of: NavigationStack { WorkflowListView(apiClient: mockClient()) })
    }

    func test_list_empty() {
        let mock = MockAPIClient()
        mock.listWorkflowsResult = .success([])
        assertDeviceSnapshotAfterTask(of: NavigationStack { WorkflowListView(apiClient: mock) })
    }

    func test_list_error() {
        let mock = MockAPIClient()
        mock.listWorkflowsResult = .failure(APIError.networkError)
        assertDeviceSnapshotAfterTask(of: NavigationStack { WorkflowListView(apiClient: mock) })
    }

    // MARK: - Detail

    func test_detail_documentWorkflowWithRuns() {
        assertDeviceSnapshotAfterTask(of: NavigationStack {
            WorkflowDetailView(workflow: documentWorkflow, apiClient: mockClient()) { _ in }
        })
    }

    func test_detail_scheduleWorkflowNoRuns() {
        let mock = MockAPIClient()
        assertDeviceSnapshotAfterTask(of: NavigationStack {
            WorkflowDetailView(workflow: scheduleWorkflow, apiClient: mock) { _ in }
        })
    }

    // MARK: - Run detail

    func test_runDetail_completed() {
        assertDeviceSnapshot(of: NavigationStack { WorkflowRunDetailView(run: completedRun) })
    }

    func test_runDetail_failed() {
        assertDeviceSnapshot(of: NavigationStack { WorkflowRunDetailView(run: failedRun) })
    }

    // MARK: - Form

    func test_form_create() {
        assertDeviceSnapshot(of: NavigationStack {
            WorkflowFormView { _ in throw APIError.invalidResponse }
        })
    }

    func test_form_editSchedule() {
        assertDeviceSnapshot(of: NavigationStack {
            WorkflowFormView(workflow: scheduleWorkflow) { _ in throw APIError.invalidResponse }
        })
    }

    func test_form_editDocument() {
        assertDeviceSnapshot(of: NavigationStack {
            WorkflowFormView(workflow: documentWorkflow) { _ in throw APIError.invalidResponse }
        })
    }

    func test_variablesSheet() {
        assertDeviceSnapshot(of: NavigationStack { WorkflowVariablesView { _ in } })
    }
}
