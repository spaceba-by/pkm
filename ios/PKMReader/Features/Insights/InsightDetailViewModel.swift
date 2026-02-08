import Foundation

/// View model for loading insight detail content (summary or report)
@MainActor
final class InsightDetailViewModel: ObservableObject {
    /// Possible states for content loading
    enum ContentState: Equatable {
        case loading
        case loaded(String)
        case error(String)

        static func == (lhs: ContentState, rhs: ContentState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading):
                true
            case let (.loaded(lhsContent), .loaded(rhsContent)):
                lhsContent == rhsContent
            case let (.error(lhsMsg), .error(rhsMsg)):
                lhsMsg == rhsMsg
            default:
                false
            }
        }
    }

    /// Current state of content loading
    @Published private(set) var contentState: ContentState = .loading

    /// The S3 key of the insight document
    let key: String

    private let apiClient: any APIClientProtocol

    init(key: String, apiClient: any APIClientProtocol) {
        self.key = key
        self.apiClient = apiClient
    }

    /// Load the insight content from the API
    func loadContent() async {
        guard case .loading = contentState else { return }

        do {
            let document = try await apiClient.getDocument(key: key)
            if let content = document.content {
                contentState = .loaded(content)
            } else {
                contentState = .loaded("*No content available*")
            }
        } catch {
            contentState = .error(error.localizedDescription)
        }
    }
}
