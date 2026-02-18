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

    /// The document being displayed
    let document: Document

    private let apiClient: any APIClientProtocol

    init(document: Document, apiClient: any APIClientProtocol) {
        self.document = document
        self.apiClient = apiClient
        self.classification = document.metadata.classification

        // If content already loaded, use it
        if let content = document.content {
            contentState = .loaded(processContent(content))
        }
    }

    /// Load the document content from the API
    func loadContent() async {
        // Skip if already loaded
        if case .loaded = contentState {
            return
        }

        contentState = .loading

        do {
            let fullDocument = try await apiClient.getDocument(key: document.id)
            if let content = fullDocument.content {
                contentState = .loaded(processContent(content))
            } else {
                contentState = .loaded("*No content available*")
            }
        } catch {
            contentState = .error(error)
        }
    }

    // MARK: - Content Processing

    /// Process content through all transformations before rendering
    func processContent(_ content: String) -> String {
        var result = content
        result = stripFrontmatter(result)
        result = renderCheckboxes(result)
        result = convertWikilinks(result)
        return result
    }

    /// Strip YAML front matter block from the start of content
    private func stripFrontmatter(_ content: String) -> String {
        // Match front matter: starts with ---, ends with --- (with optional content between)
        guard let range = content.range(
            of: #"^---\n(?:[\s\S]*?\n)?---\n?"#,
            options: .regularExpression
        ) else {
            return content
        }
        return String(content[range.upperBound...])
    }

    /// Replace markdown checkbox syntax with Unicode ballot characters
    private func renderCheckboxes(_ content: String) -> String {
        var result = content
        // Unchecked: - [ ] → - ☐ ((?m) enables multiline mode for ^ to match line starts)
        result = result.replacingOccurrences(
            of: #"(?m)^(\s*)- \[ \]"#,
            with: "$1- ☐",
            options: .regularExpression
        )
        // Checked: - [x] or - [X] → - ☑
        result = result.replacingOccurrences(
            of: #"(?m)^(\s*)- \[[xX]\]"#,
            with: "$1- ☑",
            options: .regularExpression
        )
        return result
    }

    /// Convert [[wikilinks]] to standard markdown links with pkm: scheme
    private func convertWikilinks(_ content: String) -> String {
        // First handle [[target|display]] form, then [[target]] form
        var result = content.replacingOccurrences(
            of: #"\[\[([^\]|]+)\|([^\]]+)\]\]"#,
            with: "[$2](pkm:$1)",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\[\[([^\]]+)\]\]"#,
            with: "[$1](pkm:$1)",
            options: .regularExpression
        )
        return result
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
