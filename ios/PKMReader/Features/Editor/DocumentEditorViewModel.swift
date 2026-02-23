import Foundation

/// View model for the document editor
@MainActor
final class DocumentEditorViewModel: ObservableObject {
    enum Mode: Equatable {
        case create
        case edit(Document)
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case error(String)

        static func == (lhs: SaveState, rhs: SaveState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.saving, .saving), (.saved, .saved):
                true
            case let (.error(lhsMsg), .error(rhsMsg)):
                lhsMsg == rhsMsg
            default:
                false
            }
        }
    }

    @Published var content: String
    @Published var documentKey: String
    @Published var title: String
    @Published private(set) var saveState: SaveState = .idle
    @Published var showPreview = false

    let mode: Mode
    private let apiClient: any APIClientProtocol
    private let lastModified: String?

    init(mode: Mode, apiClient: any APIClientProtocol) {
        self.mode = mode
        self.apiClient = apiClient

        switch mode {
        case .create:
            content = ""
            documentKey = ""
            title = ""
            lastModified = nil

        case let .edit(document):
            content = document.content ?? ""
            documentKey = document.id
            title = document.title
            // Use ISO 8601 formatter for the modified date
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            lastModified = formatter.string(from: document.metadata.modified)
        }
    }

    var isValid: Bool {
        switch mode {
        case .create:
            !documentKey.trimmingCharacters(in: .whitespaces).isEmpty
                && documentKey.hasSuffix(".md")
        case .edit:
            true
        }
    }

    var navigationTitle: String {
        switch mode {
        case .create: "New Document"
        case .edit: "Edit Document"
        }
    }

    func resetSaveState() {
        saveState = .idle
    }

    func save() async {
        guard isValid else { return }

        saveState = .saving

        do {
            switch mode {
            case .create:
                let trimmedKey = documentKey.trimmingCharacters(in: .whitespaces)
                let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
                _ = try await apiClient.createDocument(
                    key: trimmedKey,
                    title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                    content: content
                )
                saveState = .saved

            case .edit:
                try await apiClient.updateDocument(
                    key: documentKey,
                    content: content,
                    ifUnmodifiedSince: lastModified
                )
                saveState = .saved
            }
        } catch {
            let statusCode = (error as? APIError).flatMap { apiError -> Int? in
                if case let .httpError(code) = apiError { return code }
                return nil
            }

            if statusCode == 409 {
                saveState = .error("This document was modified elsewhere. Please reload and try again.")
            } else if statusCode == 403 {
                saveState = .error("Admin access required to save documents.")
            } else {
                saveState = .error("Failed to save: \(error.localizedDescription)")
            }
        }
    }
}
