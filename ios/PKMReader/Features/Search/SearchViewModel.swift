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
        case error(Error)

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
            case let (.error(lhsErr), .error(rhsErr)):
                lhsErr.localizedDescription == rhsErr.localizedDescription
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

    /// Current search mode
    @Published var searchMode: SearchMode = .keyword {
        didSet {
            if oldValue != searchMode {
                onSearchTextChanged()
            }
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
            let results = try await apiClient.search(query: query, limit: 20, mode: searchMode)
            guard !Task.isCancelled else { return }
            if results.isEmpty {
                state = .empty
            } else {
                state = .loaded(results)
            }
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .error(error)
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
