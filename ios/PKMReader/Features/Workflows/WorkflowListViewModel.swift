import Foundation

@MainActor
@Observable
final class WorkflowListViewModel {
    enum State: Equatable {
        case loading
        case loaded
        case error(String)
    }

    private(set) var state: State = .loading
    private(set) var workflows: [Workflow] = []
    /// Error from a mutation (toggle, delete) shown as a transient banner
    var actionError: String?

    let apiClient: any APIClientProtocol

    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    func loadWorkflows() async {
        state = .loading
        do {
            workflows = try await apiClient.listWorkflows().sorted { $0.name < $1.name }
            state = .loaded
        } catch {
            state = .error("Failed to load workflows: \(error.localizedDescription)")
        }
    }

    func createWorkflow(_ request: WorkflowRequest) async throws -> Workflow {
        let created = try await apiClient.createWorkflow(request: request)
        workflows = (workflows + [created]).sorted { $0.name < $1.name }
        return created
    }

    func updateWorkflow(id: String, request: WorkflowRequest) async throws -> Workflow {
        let updated = try await apiClient.updateWorkflow(id: id, request: request)
        replace(updated)
        return updated
    }

    func setEnabled(_ workflow: Workflow, enabled: Bool) async {
        guard workflow.enabled != enabled else { return }
        actionError = nil
        do {
            let updated = try await apiClient.updateWorkflow(
                id: workflow.id,
                request: WorkflowRequest(enabled: enabled)
            )
            replace(updated)
        } catch {
            actionError = "Failed to \(enabled ? "enable" : "disable") \(workflow.name): \(error.localizedDescription)"
        }
    }

    func deleteWorkflow(_ workflow: Workflow) async {
        actionError = nil
        do {
            try await apiClient.deleteWorkflow(id: workflow.id)
            workflows.removeAll { $0.id == workflow.id }
        } catch {
            actionError = "Failed to delete \(workflow.name): \(error.localizedDescription)"
        }
    }

    func replace(_ workflow: Workflow) {
        if let index = workflows.firstIndex(where: { $0.id == workflow.id }) {
            workflows[index] = workflow
        } else {
            workflows.append(workflow)
        }
        workflows.sort { $0.name < $1.name }
    }
}
