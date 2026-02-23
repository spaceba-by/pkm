import Foundation

/// View model for the search monitor detail screen
@MainActor
final class SearchMonitorDetailViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded
        case error(Error)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): true
            case (.loaded, .loaded): true
            case let (.error(lhsErr), .error(rhsErr)):
                lhsErr.localizedDescription == rhsErr.localizedDescription
            default: false
            }
        }
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var monitor: SearchMonitor?
    @Published private(set) var summaries: [SearchSummary] = []

    let monitorId: String
    let apiClient: any APIClientProtocol

    init(monitorId: String, apiClient: any APIClientProtocol) {
        self.monitorId = monitorId
        self.apiClient = apiClient
    }

    func loadDetail() async {
        state = .loading
        await fetchDetail()
    }

    func refresh() async {
        await fetchDetail()
    }

    func togglePauseResume() async throws {
        guard let monitor else { return }
        let newStatus: SearchMonitorStatus = monitor.status == .active ? .paused : .active
        let request = SearchMonitorRequest(status: newStatus)
        let updated = try await apiClient.updateSearchMonitor(id: monitorId, request: request)
        self.monitor = updated
    }

    func updateMonitor(request: SearchMonitorRequest) async throws -> SearchMonitor {
        let updated = try await apiClient.updateSearchMonitor(id: monitorId, request: request)
        monitor = updated
        return updated
    }

    func loadMoreSummaries() async {
        do {
            let result = try await apiClient.listSearchMonitorSummaries(monitorId: monitorId, limit: 50)
            summaries.append(contentsOf: result)
        } catch is CancellationError {
            return
        } catch {
            // Silently fail for pagination; the user already sees existing summaries
        }
    }

    private func fetchDetail() async {
        do {
            let response = try await apiClient.getSearchMonitor(id: monitorId)
            monitor = response.monitor
            summaries = response.summaries
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            state = .error(error)
        }
    }
}
