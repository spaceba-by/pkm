import Foundation

/// View model for the weekly reports list
@MainActor
final class ReportsViewModel: ObservableObject {
    /// Possible states for the reports list
    enum State: Equatable {
        case loading
        case loaded([Report])
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

    /// Load weekly reports
    func loadReports() async {
        state = .loading

        do {
            let reports = try await apiClient.listReports(limit: 20)
            if reports.isEmpty {
                state = .empty
            } else {
                state = .loaded(reports)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Refresh the reports list
    func refresh() async {
        await loadReports()
    }
}
