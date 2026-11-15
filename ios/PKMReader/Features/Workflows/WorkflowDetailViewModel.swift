import Foundation

@MainActor
@Observable
final class WorkflowDetailViewModel {
    private(set) var workflow: Workflow
    private(set) var runs: [WorkflowRun] = []
    private(set) var isLoadingRuns = false
    private(set) var isStartingRun = false
    var statusMessage: String?
    var errorMessage: String?
    private var nextCursor: String?

    let apiClient: any APIClientProtocol
    private let pageSize = 20

    init(workflow: Workflow, apiClient: any APIClientProtocol) {
        self.workflow = workflow
        self.apiClient = apiClient
    }

    var hasMoreRuns: Bool {
        nextCursor != nil
    }

    func refresh() async {
        errorMessage = nil
        do {
            workflow = try await apiClient.getWorkflow(id: workflow.id)
        } catch {
            errorMessage = "Failed to refresh workflow: \(error.localizedDescription)"
        }
        await loadRuns()
    }

    func loadRuns() async {
        isLoadingRuns = true
        defer { isLoadingRuns = false }
        do {
            let response = try await apiClient.listWorkflowRuns(
                workflowId: workflow.id,
                limit: pageSize,
                cursor: nil
            )
            runs = response.runs
            nextCursor = response.nextCursor
        } catch {
            errorMessage = "Failed to load runs: \(error.localizedDescription)"
        }
    }

    func loadMoreRuns() async {
        guard let cursor = nextCursor, !isLoadingRuns else { return }
        isLoadingRuns = true
        defer { isLoadingRuns = false }
        do {
            let response = try await apiClient.listWorkflowRuns(
                workflowId: workflow.id,
                limit: pageSize,
                cursor: cursor
            )
            runs.append(contentsOf: response.runs)
            nextCursor = response.nextCursor
        } catch {
            errorMessage = "Failed to load more runs: \(error.localizedDescription)"
        }
    }

    /// Start a manual run. Returns the run id on success.
    @discardableResult
    func runNow(documentPath: String?) async -> String? {
        isStartingRun = true
        defer { isStartingRun = false }
        errorMessage = nil
        statusMessage = nil
        let trimmed = documentPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = (trimmed?.isEmpty ?? true) ? nil : trimmed
        do {
            let response = try await apiClient.runWorkflow(id: workflow.id, documentPath: path)
            statusMessage = "Run queued. Results appear below once it finishes."
            return response.runId
        } catch {
            errorMessage = "Failed to start run: \(error.localizedDescription)"
            return nil
        }
    }

    func apply(_ updated: Workflow) {
        workflow = updated
    }
}
