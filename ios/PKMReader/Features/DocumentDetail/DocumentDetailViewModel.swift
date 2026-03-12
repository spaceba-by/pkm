import Foundation

/// View model for the document detail screen
@MainActor
final class DocumentDetailViewModel: ObservableObject {
    /// Possible states for content loading
    enum ContentState: Equatable {
        case loading
        case loaded(String)
        case error(Error)

        static func == (lhs: ContentState, rhs: ContentState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading):
                true
            case let (.loaded(lhsContent), .loaded(rhsContent)):
                lhsContent == rhsContent
            case (.error, .error):
                true
            default:
                false
            }
        }
    }

    /// Current state of content loading
    @Published private(set) var contentState: ContentState = .loading

    /// Current classification (may be updated by user)
    @Published private(set) var classification: DocumentClassification

    /// Whether a classification update is in progress
    @Published private(set) var isUpdatingClassification = false

    /// Error from the last classification update attempt
    @Published var classificationUpdateError: Error?

    /// The raw (unprocessed) content for use by the editor
    @Published private(set) var rawContent: String?

    /// The document being displayed
    let document: Document

    private let apiClient: any APIClientProtocol

    init(document: Document, apiClient: any APIClientProtocol) {
        self.document = document
        self.apiClient = apiClient
        classification = document.metadata.classification

        // If content already loaded, use it
        if let content = document.content {
            rawContent = content
            contentState = .loaded(processContent(content))
        }
    }

    /// The document with raw content populated, for use by the editor
    var documentWithContent: Document {
        Document(
            id: document.id,
            title: document.title,
            content: rawContent,
            metadata: document.metadata
        )
    }

    /// Reload the document content from the API, even if already loaded
    func reloadContent() async {
        contentState = .loading
        await fetchContent()
    }

    /// Load the document content from the API
    func loadContent() async {
        // Skip if already loaded
        if case .loaded = contentState {
            return
        }

        contentState = .loading
        await fetchContent()
    }

    private func fetchContent() async {
        do {
            let fullDocument = try await apiClient.getDocument(key: document.id)
            if let content = fullDocument.content {
                rawContent = content
                contentState = .loaded(processContent(content))
            } else {
                rawContent = ""
                contentState = .loaded("*No content available*")
            }
        } catch {
            contentState = .error(error)
        }
    }

    // MARK: - Content Processing

    /// Process content through all transformations before rendering
    func processContent(_ content: String) -> String {
        MarkdownProcessor.process(content)
    }

    /// Update the document's classification
    func updateClassification(to newClassification: DocumentClassification) async {
        guard newClassification != classification else { return }

        isUpdatingClassification = true
        classificationUpdateError = nil

        do {
            try await apiClient.updateClassification(
                documentId: document.id,
                classification: newClassification
            )
            classification = newClassification
        } catch {
            classificationUpdateError = error
        }

        isUpdatingClassification = false
    }
}
