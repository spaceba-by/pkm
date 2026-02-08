import Foundation

/// View model for the search screen
@MainActor
final class SearchViewModel: ObservableObject {
    /// Possible states for the search view
    enum State: Equatable {
        case idle
        case loading
        case loaded([Document])
        case empty
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                true
            case (.loading, .loading):
                true
            case let (.loaded(lhsDocs), .loaded(rhsDocs)):
                lhsDocs == rhsDocs
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
    @Published private(set) var state: State = .idle

    /// Current search query text
    @Published var searchText = "" {
        didSet {
            onSearchTextChanged()
        }
    }

    /// Minimum query length required
    let minimumQueryLength = 2

    let apiClient: any APIClientProtocol
    private var searchTask: Task<Void, Never>?

    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Perform a search with the current text
    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard query.count >= minimumQueryLength else {
            state = .idle
            return
        }

        state = .loading

        do {
            let results = try await apiClient.search(query: query, limit: 20)
            if results.isEmpty {
                state = .empty
            } else {
                state = .loaded(results)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func onSearchTextChanged() {
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard query.count >= minimumQueryLength else {
            state = .idle
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            await search()
        }
    }
}
