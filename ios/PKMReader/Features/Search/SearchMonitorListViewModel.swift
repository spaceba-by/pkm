import Foundation

/// View model for the search monitor list
@MainActor
final class SearchMonitorListViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded
        case empty
        case error(Error)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): true
            case (.loaded, .loaded): true
            case (.empty, .empty): true
            case let (.error(lhsErr), .error(rhsErr)):
                lhsErr.localizedDescription == rhsErr.localizedDescription
            default: false
            }
        }
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var monitors: [SearchMonitor] = []

    let apiClient: any APIClientProtocol

    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    func loadMonitors() async {
        state = .loading
        await fetchMonitors()
    }

    func refresh() async {
        await fetchMonitors()
    }

    func createMonitor(request: SearchMonitorRequest) async throws -> SearchMonitor {
        let monitor = try await apiClient.createSearchMonitor(request: request)
        monitors.insert(monitor, at: 0)
        state = .loaded
        return monitor
    }

    func deleteMonitor(id: String) async throws {
        try await apiClient.deleteSearchMonitor(id: id)
        monitors.removeAll { $0.id == id }
        if monitors.isEmpty {
            state = .empty
        }
    }

    private func fetchMonitors() async {
        do {
            let result = try await apiClient.listSearchMonitors()
            monitors = result
            state = result.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            return
        } catch {
            state = .error(error)
        }
    }
}
