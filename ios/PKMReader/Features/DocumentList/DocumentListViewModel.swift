import Foundation

/// View model for the document list screen
@MainActor
final class DocumentListViewModel: ObservableObject {
    /// Possible states for the document list
    enum State: Equatable {
        case loading
        case loaded([Document])
        case empty
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
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
    @Published private(set) var state: State = .loading

    /// Currently selected classification filter
    @Published var selectedClassification: DocumentClassification?

    /// Current search text
    @Published var searchText = ""

    /// Whether there are more pages to load
    private(set) var hasMorePages = false

    /// Cursor for the next page
    private var nextCursor: String?

    /// API client for fetching documents
    let apiClient: any APIClientProtocol

    /// Initialize with an API client
    /// - Parameter apiClient: The API client to use for fetching documents
    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Load the initial page of documents
    func loadDocuments() async {
        state = .loading
        nextCursor = nil

        do {
            let response = try await apiClient.listDocuments(
                classification: selectedClassification,
                limit: 50,
                cursor: nil
            )

            hasMorePages = response.nextCursor != nil
            nextCursor = response.nextCursor

            if response.documents.isEmpty {
                state = .empty
            } else {
                state = .loaded(response.documents)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Load the next page of documents
    func loadNextPage() async {
        guard hasMorePages, let cursor = nextCursor else { return }

        do {
            let response = try await apiClient.listDocuments(
                classification: selectedClassification,
                limit: 50,
                cursor: cursor
            )

            hasMorePages = response.nextCursor != nil
            nextCursor = response.nextCursor

            if case .loaded(var currentDocs) = state {
                currentDocs.append(contentsOf: response.documents)
                state = .loaded(currentDocs)
            }
        } catch {
            // Keep existing documents on pagination error
            // Could optionally show a toast/alert here
        }
    }

    /// Refresh the document list
    func refresh() async {
        await loadDocuments()
    }
}
