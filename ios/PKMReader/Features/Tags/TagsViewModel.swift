import Foundation

/// View model for the tags list screen
@MainActor
final class TagsViewModel: ObservableObject {
    /// Possible states for the tags list
    enum State: Equatable {
        case loading
        case loaded([Tag])
        case empty
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading):
                true
            case let (.loaded(lhsTags), .loaded(rhsTags)):
                lhsTags == rhsTags
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

    /// Load all tags
    func loadTags() async {
        state = .loading

        do {
            let tags = try await apiClient.listTags()
            if tags.isEmpty {
                state = .empty
            } else {
                let sorted = tags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                state = .loaded(sorted)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Refresh the tags list
    func refresh() async {
        await loadTags()
    }
}
