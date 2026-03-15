import Foundation

/// View model for the task list screen
@MainActor
@Observable
final class TaskListViewModel {
    enum State: Equatable {
        case loading
        case loaded
        case error(String)
    }

    enum StatusFilter: String, CaseIterable {
        case open
        case completed
        case all

        var displayName: String {
            rawValue.capitalized
        }
    }

    private(set) var state: State = .loading
    private(set) var tasks: [ExtractedTask] = []
    private(set) var stats: TaskStatsResponse?
    var selectedStatus: StatusFilter = .open
    private var nextCursor: String?
    private var isLoadingMore = false

    private let apiClient: any APIClientProtocol

    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    var hasMorePages: Bool {
        nextCursor != nil
    }

    func loadTasks() async {
        state = .loading
        do {
            let response = try await apiClient.listTasks(
                status: selectedStatus.rawValue,
                limit: 50,
                cursor: nil
            )
            tasks = response.tasks
            nextCursor = response.nextCursor
            state = .loaded
        } catch {
            state = .error("Failed to load tasks")
        }
    }

    func loadMoreTasks() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await apiClient.listTasks(
                status: selectedStatus.rawValue,
                limit: 50,
                cursor: cursor
            )
            tasks.append(contentsOf: response.tasks)
            nextCursor = response.nextCursor
        } catch {
            // Silently fail for pagination errors
        }
    }

    func loadStats() async {
        do {
            stats = try await apiClient.getTaskStats()
        } catch {
            // Stats are non-critical
        }
    }

    func refresh() async {
        await loadTasks()
        await loadStats()
    }

    func changeFilter(to status: StatusFilter) async {
        selectedStatus = status
        await loadTasks()
    }
}
