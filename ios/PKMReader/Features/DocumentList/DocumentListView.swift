import SwiftUI

/// Main view for displaying the list of documents with integrated search
struct DocumentListView: View {
    @StateObject private var viewModel: DocumentListViewModel
    @State private var showingFilter = false
    @State private var showingEditor = false
    @State private var showingMonitors = false

    init(apiClient: any APIClientProtocol) {
        _viewModel = StateObject(wrappedValue: DocumentListViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSearchActive {
                    searchContent
                } else {
                    browseContent
                }
            }
            .navigationTitle("Documents")
            .searchable(
                text: $viewModel.searchText,
                prompt: "Search documents..."
            )
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

                        if !viewModel.isSearchActive {
                            sortMenu
                        }

                        filterButton

                        Button {
                            showingMonitors = true
                        } label: {
                            Image(systemName: "binoculars")
                        }
                        .accessibilityLabel("Search monitors")
                        .accessibilityIdentifier("SearchMonitorsLink")
                    }
                }

                if viewModel.isSearchActive {
                    ToolbarItem(placement: .topBarLeading) {
                        Picker("Mode", selection: $viewModel.searchMode) {
                            ForEach(SearchMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        .accessibilityIdentifier("SearchModePicker")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                DocumentEditorView(
                    mode: .create,
                    apiClient: viewModel.apiClient,
                    onSave: { Task { await viewModel.loadDocuments() } }
                )
            }
            .sheet(isPresented: $showingFilter) {
                FilterSheet(
                    selectedClassification: $viewModel.selectedClassification,
                    selectedTag: $viewModel.selectedTag,
                    tags: viewModel.tags,
                    onApply: {
                        Task { await viewModel.loadDocuments() }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .navigationDestination(isPresented: $showingMonitors) {
                SearchMonitorListView(apiClient: viewModel.apiClient)
            }
            .refreshable {
                if viewModel.isSearchActive {
                    await viewModel.search()
                } else {
                    await viewModel.refresh()
                }
            }
        }
        .task {
            await viewModel.loadDocuments()
        }
        .task {
            await viewModel.loadTags()
        }
    }

    // MARK: - Browse Content

    @ViewBuilder private var browseContent: some View {
        switch viewModel.state {
        case .loading:
            LoadingView(message: "Loading documents...")

        case let .loaded(documents):
            documentList(documents)

        case let .error(error):
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
            } else if let tag = viewModel.selectedTag {
                EmptyStateView(
                    icon: "doc.text",
                    title: "No Documents",
                    message: "No documents tagged \"\(tag.name)\""
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

    // MARK: - Search Content

    @ViewBuilder private var searchContent: some View {
        switch viewModel.searchState {
        case .idle:
            EmptyStateView(
                icon: "magnifyingglass",
                title: "Search Documents",
                message: "Enter at least 2 characters to search"
            )

        case .loading:
            LoadingView(message: "Searching...")

        case let .loaded(documents):
            searchResultsList(documents)

        case .empty:
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No Results",
                message: "No documents match your search"
            )

        case let .error(error):
            ErrorView(error: error) {
                Task { await viewModel.search() }
            }
        }
    }

    // MARK: - Toolbar Items

    private var sortMenu: some View {
        Menu {
            ForEach(DocumentSortOrder.allCases, id: \.self) { order in
                Button {
                    viewModel.sortOrder = order
                    Task {
                        await viewModel.applySortOrder()
                    }
                } label: {
                    if viewModel.sortOrder == order {
                        Label(order.displayName, systemImage: "checkmark")
                    } else {
                        Text(order.displayName)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort documents")
        .accessibilityIdentifier("SortButton")
    }

    private var filterButton: some View {
        Button {
            showingFilter = true
        } label: {
            Image(systemName: viewModel.hasActiveFilter
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filter documents")
        .accessibilityHint("Opens filter options by classification and tag")
        .accessibilityIdentifier("FilterButton")
    }

    // MARK: - Lists

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
            DocumentDetailView(document: document, apiClient: viewModel.apiClient, onDelete: {
                Task { await viewModel.loadDocuments() }
            })
        }
        .accessibilityIdentifier("DocumentList")
    }

    private func searchResultsList(_ documents: [Document]) -> some View {
        List {
            ForEach(documents) { document in
                NavigationLink(value: document) {
                    DocumentRowView(document: document)
                }
                .accessibilityIdentifier("SearchResult_\(document.id)")
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Document.self) { document in
            DocumentDetailView(document: document, apiClient: viewModel.apiClient)
        }
        .accessibilityIdentifier("SearchResultsList")
    }
}

#Preview {
    DocumentListView(apiClient: PreviewAPIClient())
}

/// Preview-only mock API client
private final class PreviewAPIClient: APIClientProtocol, @unchecked Sendable {
    func listDocuments(
        classification _: DocumentClassification?,
        limit _: Int,
        cursor _: String?,
        sort _: DocumentSortOrder? = nil
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

    func search(query _: String, limit _: Int, mode _: SearchMode) async throws -> [Document] {
        []
    }

    func listTags() async throws -> [Tag] {
        []
    }

    func listClassifications() async throws -> [ClassificationCount] {
        []
    }

    func listSummaries(limit _: Int) async throws -> [Summary] {
        []
    }

    func listReports(limit _: Int) async throws -> [Report] {
        []
    }

    func documentsByTag(tag _: String, limit _: Int) async throws -> [Document] {
        []
    }

    func updateClassification(documentId _: String, classification _: DocumentClassification) async throws {}
    func createDocument(key: String, title: String?, content _: String) async throws -> CreateDocumentResponse {
        CreateDocumentResponse(key: key, title: title ?? key, createdAt: "2024-01-01T00:00:00Z")
    }

    func updateDocument(key _: String, content _: String, ifUnmodifiedSince _: String?) async throws {}
    func deleteDocument(key _: String) async throws {}
    func getGraphData() async throws -> GraphDataResponse {
        GraphDataResponse(nodes: [], edges: [], nodeCount: 0, edgeCount: 0)
    }

    func listSearchMonitors() async throws -> [SearchMonitor] {
        []
    }

    func getSearchMonitor(id _: String) async throws -> SearchMonitorDetailResponse {
        throw APIError.invalidResponse
    }

    func createSearchMonitor(request _: SearchMonitorRequest) async throws -> SearchMonitor {
        throw APIError.invalidResponse
    }

    func updateSearchMonitor(id _: String, request _: SearchMonitorRequest) async throws -> SearchMonitor {
        throw APIError.invalidResponse
    }

    func deleteSearchMonitor(id _: String) async throws {}
    func listSearchMonitorSummaries(monitorId _: String, limit _: Int) async throws -> [SearchSummary] {
        []
    }

    func getSearchMonitorSummary(monitorId _: String, timestamp _: String) async throws -> SearchSummary {
        throw APIError.invalidResponse
    }

    func registerDevice(request: DeviceRegistrationRequest) async throws -> DeviceRegistrationResponse {
        DeviceRegistrationResponse(deviceId: request.deviceId, registered: true)
    }

    func unregisterDevice(deviceId _: String) async throws {}
    func listNotifications() async throws -> NotificationListResponse {
        NotificationListResponse(notifications: [], count: 0)
    }

    func markNotificationRead(id _: String) async throws {}
    func markSummaryViewed(date _: String) async throws {}
    func markReportViewed(week _: String) async throws {}
    func markSearchSummaryViewed(monitorId _: String, timestamp _: String) async throws {}
    func markAllInsightsViewed() async throws {}

    func getUnviewedCount() async throws -> Int {
        0
    }

    func sendChatMessage(message _: String, conversationId _: String?) async throws -> ChatSendResponse {
        throw APIError.invalidResponse
    }

    func listConversations() async throws -> [ChatConversation] {
        []
    }

    func getConversationMessages(conversationId _: String) async throws -> [ChatMessage] {
        []
    }
}
