import SwiftUI

/// View displaying documents filtered by a specific tag
struct TagDocumentsView: View {
    @StateObject private var viewModel: TagDocumentsViewModel

    init(tag: Tag, apiClient: any APIClientProtocol) {
        _viewModel = StateObject(wrappedValue: TagDocumentsViewModel(
            tag: tag,
            apiClient: apiClient
        ))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingView(message: "Loading documents...")

            case .loaded(let documents):
                documentsList(documents)

            case .empty:
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Documents",
                    message: "No documents found with tag \"\(viewModel.tag.name)\""
                )

            case .error(let errorMessage):
                ErrorView(error: GenericError(message: errorMessage)) {
                    Task { await viewModel.loadDocuments() }
                }
            }
        }
        .navigationTitle("#\(viewModel.tag.name)")
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadDocuments()
        }
        .accessibilityIdentifier("TagDocumentsView")
    }

    private func documentsList(_ documents: [Document]) -> some View {
        List {
            ForEach(documents) { document in
                NavigationLink(value: document) {
                    DocumentRowView(document: document)
                }
                .accessibilityIdentifier("TagDocumentRow_\(document.id)")
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Document.self) { document in
            DocumentDetailView(document: document, apiClient: viewModel.apiClient)
        }
        .accessibilityIdentifier("TagDocumentsList")
    }
}

/// Simple error wrapper for displaying error messages
private struct GenericError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
