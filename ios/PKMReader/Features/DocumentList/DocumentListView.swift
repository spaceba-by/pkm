import SwiftUI

/// Main view for displaying the list of documents
struct DocumentListView: View {
    @StateObject private var viewModel: DocumentListViewModel
    @State private var showingFilter = false

    init(apiClient: any APIClientProtocol) {
        _viewModel = StateObject(wrappedValue: DocumentListViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    LoadingView(message: "Loading documents...")

                case .loaded(let documents):
                    documentList(documents)

                case .error(let error):
                    ErrorView(error: error) {
                        Task { await viewModel.loadDocuments() }
                    }

                case .empty:
                    if let classification = viewModel.selectedClassification {
                        EmptyStateView(
                            icon: "doc.text",
                            title: "No Documents",
                            message: "No \(classification.displayName.lowercased()) documents found"
                        )
                    } else {
                        EmptyStateView(
                            icon: "doc.text",
                            title: "No Documents",
                            message: "Your vault is empty"
                        )
                    }
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    filterButton
                }
            }
            .sheet(isPresented: $showingFilter) {
                FilterSheet(
                    selectedClassification: $viewModel.selectedClassification,
                    onApply: {
                        Task { await viewModel.loadDocuments() }
                    }
                )
                .presentationDetents([.medium])
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.loadDocuments()
        }
    }

    private var filterButton: some View {
        Button {
            showingFilter = true
        } label: {
            Image(systemName: viewModel.selectedClassification != nil
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filter documents")
        .accessibilityHint("Opens filter options by classification")
        .accessibilityIdentifier("FilterButton")
    }

    private func documentList(_ documents: [Document]) -> some View {
        List {
            ForEach(documents) { document in
                NavigationLink(value: document) {
                    DocumentRowView(document: document)
                }
                .accessibilityIdentifier("DocumentRow_\(document.id)")
            }

            if viewModel.hasMorePages {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .task {
                        await viewModel.loadNextPage()
                    }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Document.self) { document in
            DocumentDetailView(document: document, apiClient: viewModel.apiClient)
        }
        .accessibilityIdentifier("DocumentList")
    }
}

#Preview {
    DocumentListView(apiClient: PreviewAPIClient())
}

/// Preview-only mock API client
private final class PreviewAPIClient: APIClientProtocol, @unchecked Sendable {
    func listDocuments(
        classification: DocumentClassification?,
        limit: Int,
        cursor: String?
    ) async throws -> DocumentListResponse {
        DocumentListResponse(documents: [], nextCursor: nil)
    }

    func getDocument(key: String) async throws -> Document {
        Document(
            id: key,
            title: "Preview Document",
            content: "# Preview\n\nThis is a preview document.",
            metadata: DocumentMetadata(
                classification: .reference,
                tags: ["preview"],
                linksTo: [],
                entities: nil,
                created: Date(),
                modified: Date(),
                hasFrontmatter: false
            )
        )
    }

    func search(query: String, limit: Int) async throws -> [Document] { [] }
    func listTags() async throws -> [Tag] { [] }
    func listClassifications() async throws -> [ClassificationCount] { [] }
    func listSummaries(limit: Int) async throws -> [Summary] { [] }
    func listReports(limit: Int) async throws -> [Report] { [] }
    func documentsByTag(tag: String, limit: Int) async throws -> [Document] { [] }
    func updateClassification(documentId: String, classification: DocumentClassification) async throws {}
}
