import Foundation

/// View model for the document list screen
@MainActor
final class DocumentListViewModel: ObservableObject {
    /// Possible states for the document list (browse mode)
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

    /// Possible states for search results
    enum SearchState: Equatable {
        case idle
        case loading
        case loaded([Document])
        case empty
        case error(Error)

        static func == (lhs: SearchState, rhs: SearchState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                true
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

    /// Current state of the browse view
    @Published private(set) var state: State = .loading

    /// Current state of search results
    @Published private(set) var searchState: SearchState = .idle

    /// Currently selected classification filter
    @Published var selectedClassification: DocumentClassification?

    /// Currently selected tag filter
    @Published var selectedTag: Tag?

    /// Current sort order for documents
    @Published var sortOrder: DocumentSortOrder = .modifiedDate

    /// Current search text
    @Published var searchText = "" {
        didSet {
            onSearchTextChanged()
        }
    }

    /// Current search mode
    @Published var searchMode: SearchMode = .keyword {
        didSet {
            if oldValue != searchMode {
                onSearchTextChanged()
            }
        }
    }

    /// Available tags for filtering
    @Published private(set) var tags: [Tag] = []

    /// Whether search is active (user has typed enough characters)
    var isSearchActive: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumQueryLength
    }

    /// Whether any filter (classification or tag) is active
    var hasActiveFilter: Bool {
        selectedClassification != nil || selectedTag != nil
    }

    /// Minimum query length required for search
    let minimumQueryLength = 2

    /// Whether there are more pages to load
    private(set) var hasMorePages = false

    /// Cursor for the next page
    private var nextCursor: String?

    /// API client for fetching documents
    let apiClient: any APIClientProtocol

    /// Monotonic counter incremented on each load; used to discard stale responses
    private var loadGeneration: UInt64 = 0

    /// Task for debounced search
    private var searchTask: Task<Void, Never>?

    /// Initialize with an API client
    /// - Parameter apiClient: The API client to use for fetching documents
    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Browse Mode

    /// Load the initial page of documents
    func loadDocuments() async {
        loadGeneration &+= 1
        state = .loading
        nextCursor = nil
        await fetchDocuments()
    }

    /// Load the next page of documents (only in browse mode without tag filter)
    func loadNextPage() async {
        guard hasMorePages, let cursor = nextCursor else { return }
        let generation = loadGeneration

        do {
            let response = try await apiClient.listDocuments(
                classification: selectedClassification,
                limit: 50,
                cursor: cursor,
                sort: sortOrder
            )

            guard generation == loadGeneration else { return }

            hasMorePages = response.nextCursor != nil
            nextCursor = response.nextCursor

            if case var .loaded(currentDocs) = state {
                currentDocs.append(contentsOf: response.documents)
                state = .loaded(sortedDocuments(currentDocs))
            }
        } catch is CancellationError {
            return
        } catch {
            hasMorePages = false
            nextCursor = nil
        }
    }

    /// Refresh the document list (keeps existing data visible)
    func refresh() async {
        nextCursor = nil
        await fetchDocuments()
    }

    /// Reload documents from API when sort order changes
    func applySortOrder() async {
        await loadDocuments()
    }

    // MARK: - Search

    /// Perform a search with the current text
    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard query.count >= minimumQueryLength else {
            searchState = .idle
            return
        }

        searchState = .loading

        do {
            let results = try await apiClient.search(query: query, limit: 20, mode: searchMode)
            guard !Task.isCancelled else { return }
            if results.isEmpty {
                searchState = .empty
            } else {
                searchState = .loaded(results)
            }
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            guard !Task.isCancelled else { return }
            searchState = .error(error)
        }
    }

    // MARK: - Tags

    /// Load available tags for the filter sheet
    func loadTags() async {
        do {
            let fetchedTags = try await apiClient.listTags()
            tags = fetchedTags.sorted {
                if $0.documentCount != $1.documentCount {
                    return $0.documentCount > $1.documentCount
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        } catch is CancellationError {
            return
        } catch {
            // Tags are non-critical; silently fail
        }
    }

    // MARK: - Private

    private func fetchDocuments() async {
        let generation = loadGeneration

        do {
            let documents: [Document]

            if let tag = selectedTag {
                // Fetch by tag, then optionally filter by classification client-side
                var tagDocs = try await apiClient.documentsByTag(tag: tag.name, limit: 50)
                if let classification = selectedClassification {
                    tagDocs = tagDocs.filter { $0.metadata.classification == classification }
                }
                documents = tagDocs
            } else {
                let response = try await apiClient.listDocuments(
                    classification: selectedClassification,
                    limit: 50,
                    cursor: nil,
                    sort: sortOrder
                )

                guard generation == loadGeneration else { return }

                hasMorePages = response.nextCursor != nil
                nextCursor = response.nextCursor
                documents = response.documents
            }

            guard generation == loadGeneration else { return }

            if selectedTag != nil {
                hasMorePages = false
                nextCursor = nil
            }

            if documents.isEmpty {
                state = .empty
            } else {
                state = .loaded(sortedDocuments(documents))
            }
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            state = .error(error)
        }
    }

    private func onSearchTextChanged() {
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard query.count >= minimumQueryLength else {
            searchState = .idle
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            await search()
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
}
