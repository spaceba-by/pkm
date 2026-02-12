import Foundation

/// View model for documents filtered by a specific tag
@MainActor
final class TagDocumentsViewModel: ObservableObject {
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

    /// The tag being browsed
    let tag: Tag

    let apiClient: any APIClientProtocol

    init(tag: Tag, apiClient: any APIClientProtocol) {
        self.tag = tag
        self.apiClient = apiClient
    }

    /// Load documents for this tag
    func loadDocuments() async {
        state = .loading

        do {
            let documents = try await apiClient.documentsByTag(tag: tag.name, limit: 50)
            if documents.isEmpty {
                state = .empty
            } else {
                state = .loaded(documents)
            }
        } catch {
            state = .error(error)
        }
    }

    /// Refresh the document list
    func refresh() async {
        await loadDocuments()
    }
}
