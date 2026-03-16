import Foundation

@MainActor
@Observable
final class DispatchListViewModel {
    enum State: Equatable {
        case loading
        case loaded
        case error(String)
    }

    enum StatusFilter: String, CaseIterable {
        case all
        case pending
        case running
        case completed
        case failed

        var displayName: String { rawValue.capitalized }
    }

    private(set) var state: State = .loading
    private(set) var jobs: [DispatchJob] = []
    private(set) var agentTypes: [AgentType] = []
    var selectedStatus: StatusFilter = .all
    private var nextCursor: String?
    private var isLoadingMore = false

    let apiClient: any APIClientProtocol

    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    func loadJobs() async {
        state = .loading
        do {
            let statusParam = selectedStatus == .all ? nil : selectedStatus.rawValue
            let response = try await apiClient.listJobs(
                status: statusParam,
                limit: 50,
                cursor: nil
            )
            jobs = response.jobs
            nextCursor = response.nextCursor
            state = .loaded
        } catch {
            state = .error("Failed to load jobs: \(error.localizedDescription)")
        }
    }

    func loadMoreJobs() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let statusParam = selectedStatus == .all ? nil : selectedStatus.rawValue
            let response = try await apiClient.listJobs(
                status: statusParam,
                limit: 50,
                cursor: cursor
            )
            jobs.append(contentsOf: response.jobs)
            nextCursor = response.nextCursor
        } catch {
            // Silently fail for pagination
        }
    }

    func loadAgentTypes() async {
        do {
            agentTypes = try await apiClient.listAgentTypes()
        } catch {
            // Non-critical, continue
        }
    }

    func changeFilter(to status: StatusFilter) async {
        selectedStatus = status
        await loadJobs()
    }

    func createJob(taskDescription: String, agentType: String, contextPaths: [String]?) async throws -> CreateJobResponse {
        let response = try await apiClient.createJob(
            taskDescription: taskDescription,
            contextPaths: contextPaths,
            agentType: agentType
        )
        // Reload jobs to show the new one
        await loadJobs()
        return response
    }
}
