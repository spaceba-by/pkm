import Foundation

/// View model for the document list screen
@MainActor
final class DocumentListViewModel: ObservableObject {
    /// Possible states for the document list
    enum State: Equatable {
        case loading
        case loaded([Document])
        case empty
        case error(Error)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
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
    @Published private(set) var state: State = .loading

    /// Currently selected classification filter
    @Published var selectedClassification: DocumentClassification?

    /// Current sort order for documents
    @Published var sortOrder: DocumentSortOrder = .modifiedDate

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
        await fetchDocuments()
    }

    /// Load the next page of documents
    func loadNextPage() async {
        guard hasMorePages, let cursor = nextCursor else { return }

        do {
            let response = try await apiClient.listDocuments(
                classification: selectedClassification,
                limit: 50,
                cursor: cursor,
                sort: sortOrder
            )

            hasMorePages = response.nextCursor != nil
            nextCursor = response.nextCursor

            if case .loaded(var currentDocs) = state {
                currentDocs.append(contentsOf: response.documents)
                state = .loaded(sortedDocuments(currentDocs))
            }
        } catch is CancellationError {
            return
        } catch {
            // Keep existing documents on pagination error,
            // but stop further pagination attempts after a failure.
            hasMorePages = false
            nextCursor = nil
        }
    }

    /// Refresh the document list (keeps existing data visible)
    func refresh() async {
        nextCursor = nil
        await fetchDocuments()
    }

    private func fetchDocuments() async {
        do {
            let response = try await apiClient.listDocuments(
                classification: selectedClassification,
                limit: 50,
                cursor: nil,
                sort: sortOrder
            )

            hasMorePages = response.nextCursor != nil
            nextCursor = response.nextCursor

            if response.documents.isEmpty {
                state = .empty
            } else {
                state = .loaded(sortedDocuments(response.documents))
            }
        } catch is CancellationError {
            return
        } catch {
            state = .error(error)
        }
    }

    /// Sort documents by the selected sort order (most recent first)
    private func sortedDocuments(_ documents: [Document]) -> [Document] {
        documents.sorted { lhs, rhs in
            switch sortOrder {
            case .modifiedDate:
                lhs.metadata.modified > rhs.metadata.modified
            case .createdDate:
                lhs.metadata.created > rhs.metadata.created
            }
        }
    }

    /// Reload documents from API when sort order changes
    func applySortOrder() async {
        await loadDocuments()
    }
}
