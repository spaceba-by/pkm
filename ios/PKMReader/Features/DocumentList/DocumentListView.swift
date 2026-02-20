import SwiftUI

/// Main view for displaying the list of documents
struct DocumentListView: View {
    @StateObject private var viewModel: DocumentListViewModel
    @State private var showingFilter = false
    @State private var showingEditor = false

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
                    HStack(spacing: 12) {
                        Button {
                            showingEditor = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Create document")
                        .accessibilityIdentifier("CreateDocumentButton")

                        sortMenu

                        filterButton
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                DocumentEditorView(
                    mode: .create,
                    apiClient: viewModel.apiClient
                )
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

    private var sortMenu: some View {
        Menu {
            Picker("Sort Order", selection: $viewModel.sortOrder) {
                Text("Modified Date").tag(DocumentSortOrder.modifiedDate)
                Text("Created Date").tag(DocumentSortOrder.createdDate)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort documents")
        .accessibilityIdentifier("SortButton")
        .onChange(of: viewModel.sortOrder) {
            viewModel.applySortOrder()
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

    func search(query: String, limit: Int, mode: SearchMode) async throws -> [Document] { [] }
    func listTags() async throws -> [Tag] { [] }
    func listClassifications() async throws -> [ClassificationCount] { [] }
    func listSummaries(limit: Int) async throws -> [Summary] { [] }
    func listReports(limit: Int) async throws -> [Report] { [] }
    func documentsByTag(tag: String, limit: Int) async throws -> [Document] { [] }
    func updateClassification(documentId: String, classification: DocumentClassification) async throws {}
    func createDocument(key: String, title: String?, content: String) async throws -> CreateDocumentResponse {
        CreateDocumentResponse(key: key, title: title ?? key, createdAt: "2024-01-01T00:00:00Z")
    }
    func updateDocument(key: String, content: String, ifUnmodifiedSince: String?) async throws {}
    func deleteDocument(key: String) async throws {}
    func getGraphData() async throws -> GraphDataResponse {
        GraphDataResponse(nodes: [], edges: [], nodeCount: 0, edgeCount: 0)
    }
}
