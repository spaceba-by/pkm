import Foundation

/// View model for the daily summaries list
@MainActor
final class SummariesViewModel: ObservableObject {
    /// Possible states for the summaries list
    enum State: Equatable {
        case loading
        case loaded([Summary])
        case empty
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading):
                true
            case let (.loaded(lhsItems), .loaded(rhsItems)):
                lhsItems.map(\.id) == rhsItems.map(\.id)
            case (.empty, .empty):
                true
            case let (.error(lhsMsg), .error(rhsMsg)):
                lhsMsg == rhsMsg
            default:
                false
            }
        }
    }

    /// Current state of the view
    @Published private(set) var state: State = .loading

    let apiClient: any APIClientProtocol

    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Load daily summaries
    func loadSummaries() async {
        state = .loading

        do {
            let summaries = try await apiClient.listSummaries(limit: 30)
            if summaries.isEmpty {
                state = .empty
            } else {
                state = .loaded(summaries)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Refresh the summaries list
    func refresh() async {
        await loadSummaries()
    }
}
