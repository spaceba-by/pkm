import XCTest
@testable import PKMReader

@MainActor
final class DocumentListViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: DocumentListViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
        sut = DocumentListViewModel(apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState() {
        XCTAssertEqual(sut.state, .loading)
        XCTAssertFalse(sut.hasMorePages)
        XCTAssertNil(sut.selectedClassification)
        XCTAssertEqual(sut.searchText, "")
        XCTAssertEqual(sut.sortOrder, .modifiedDate)
        XCTAssertEqual(sut.searchState, .idle)
        XCTAssertEqual(sut.searchMode, .keyword)
        XCTAssertNil(sut.selectedTag)
        XCTAssertTrue(sut.tags.isEmpty)
        XCTAssertFalse(sut.isSearchActive)
        XCTAssertFalse(sut.hasActiveFilter)
    }

    // MARK: - Load Documents

    func test_loadDocuments_success_updatesStateToLoaded() async {
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: TestFixtures.sampleDocuments, nextCursor: nil)
        )
        await sut.loadDocuments()

        if case .loaded(let loadedDocs) = sut.state {
            XCTAssertEqual(loadedDocs.count, 3)
            XCTAssertEqual(loadedDocs.first?.id, "ideas/new-feature.md")
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
    }

    func test_loadDocuments_emptyResult_updatesStateToEmpty() async {
        mockAPIClient.listDocumentsResult = .success(DocumentListResponse(documents: [], nextCursor: nil))
        await sut.loadDocuments()
        XCTAssertEqual(sut.state, .empty)
    }

    func test_loadDocuments_failure_updatesStateToError() async {
        mockAPIClient.listDocumentsResult = .failure(APIError.invalidResponse)
        await sut.loadDocuments()
        if case .error = sut.state { } else { XCTFail("Expected error state") }
    }

    func test_loadDocuments_callsAPIWithCorrectParameters() async {
        mockAPIClient.listDocumentsResult = .success(DocumentListResponse(documents: [], nextCursor: nil))
        await sut.loadDocuments()
        XCTAssertEqual(mockAPIClient.listDocumentsCallCount, 1)
        XCTAssertNil(mockAPIClient.lastListDocumentsClassification)
        XCTAssertEqual(mockAPIClient.lastListDocumentsLimit, 50)
        XCTAssertNil(mockAPIClient.lastListDocumentsCursor)
        XCTAssertEqual(mockAPIClient.lastListDocumentsSort, .modifiedDate)
    }

    func test_loadDocuments_withClassification_passesFilterToAPI() async {
        sut.selectedClassification = .meeting
        mockAPIClient.listDocumentsResult = .success(DocumentListResponse(documents: [], nextCursor: nil))
        await sut.loadDocuments()
        XCTAssertEqual(mockAPIClient.lastListDocumentsClassification, .meeting)
    }

    // MARK: - Pagination

    func test_loadDocuments_withNextCursor_setsHasMorePages() async {
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: TestFixtures.sampleDocuments, nextCursor: "next")
        )
        await sut.loadDocuments()
        XCTAssertTrue(sut.hasMorePages)
    }

    func test_loadDocuments_withoutNextCursor_hasNoMorePages() async {
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: TestFixtures.sampleDocuments, nextCursor: nil)
        )
        await sut.loadDocuments()
        XCTAssertFalse(sut.hasMorePages)
    }

    func test_loadNextPage_whenNoMorePages_doesNotCallAPI() async {
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: TestFixtures.sampleDocuments, nextCursor: nil)
        )
        await sut.loadDocuments()
        mockAPIClient.reset()
        await sut.loadNextPage()
        XCTAssertEqual(mockAPIClient.listDocumentsCallCount, 0)
    }

    func test_loadNextPage_appendsDocuments() async {
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [TestFixtures.sampleDocument], nextCursor: "page2")
        )
        await sut.loadDocuments()
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [TestFixtures.sampleMeetingDocument], nextCursor: nil)
        )
        await sut.loadNextPage()

        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, 2)
            XCTAssertEqual(docs[0].id, "meetings/weekly.md")  // Jan 2 (newer)
            XCTAssertEqual(docs[1].id, "test/sample.md")      // Jan 1 (older)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func test_loadNextPage_maintainsSortOrder() async {
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [TestFixtures.sampleDocument], nextCursor: "page2")
        )
        await sut.loadDocuments()
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [TestFixtures.sampleIdeaDocument], nextCursor: nil)
        )
        await sut.loadNextPage()

        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, 2)
            XCTAssertEqual(docs[0].id, "ideas/new-feature.md")
            XCTAssertEqual(docs[1].id, "test/sample.md")
        } else {
            XCTFail("Expected loaded state")
        }
    }

    // MARK: - State Equality

    func test_state_equality() {
        let docs = TestFixtures.sampleDocuments
        XCTAssertEqual(DocumentListViewModel.State.loaded(docs), DocumentListViewModel.State.loaded(docs))
        XCTAssertEqual(
            DocumentListViewModel.State.error(APIError.networkError),
            DocumentListViewModel.State.error(APIError.networkError)
        )
        XCTAssertNotEqual(DocumentListViewModel.State.loading, DocumentListViewModel.State.empty)
        XCTAssertNotEqual(DocumentListViewModel.State.loaded(docs), DocumentListViewModel.State.empty)
    }

    // MARK: - Refresh

    func test_refresh_reloadsDocuments() async {
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [TestFixtures.sampleDocument], nextCursor: nil)
        )
        await sut.loadDocuments()
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: TestFixtures.sampleDocuments, nextCursor: nil)
        )
        await sut.refresh()

        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, TestFixtures.sampleDocuments.count)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    // MARK: - CancellationError Handling

    func test_loadDocuments_cancellationError_doesNotSetErrorState() async {
        mockAPIClient.listDocumentsResult = .failure(CancellationError())
        await sut.loadDocuments()
        if case .error = sut.state { XCTFail("CancellationError should not produce error state") }
    }

    func test_refresh_cancellationError_keepsExistingState() async {
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: TestFixtures.sampleDocuments, nextCursor: nil)
        )
        await sut.loadDocuments()
        mockAPIClient.listDocumentsResult = .failure(CancellationError())
        await sut.refresh()

        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, TestFixtures.sampleDocuments.count)
        } else {
            XCTFail("Expected loaded state preserved, got \(sut.state)")
        }
    }

    // MARK: - Pagination Error Handling

    func test_loadNextPage_error_stopsPagination() async {
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [TestFixtures.sampleDocument], nextCursor: "page2")
        )
        await sut.loadDocuments()
        XCTAssertTrue(sut.hasMorePages)

        mockAPIClient.listDocumentsResult = .failure(APIError.networkError)
        await sut.loadNextPage()
        XCTAssertFalse(sut.hasMorePages)
        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, 1)
        } else {
            XCTFail("Expected loaded state preserved")
        }
    }

    func test_loadNextPage_cancellationError_doesNotStopPagination() async {
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [TestFixtures.sampleDocument], nextCursor: "page2")
        )
        await sut.loadDocuments()
        mockAPIClient.listDocumentsResult = .failure(CancellationError())
        await sut.loadNextPage()
        XCTAssertTrue(sut.hasMorePages)
        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, 1)
        } else {
            XCTFail("Expected loaded state preserved")
        }
    }

    // MARK: - Sort Order

    func test_loadDocuments_sortsByModifiedDateDescending() async {
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: TestFixtures.sampleDocuments, nextCursor: nil)
        )
        await sut.loadDocuments()

        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs[0].id, "ideas/new-feature.md")   // Jan 3
            XCTAssertEqual(docs[1].id, "meetings/weekly.md")     // Jan 2
            XCTAssertEqual(docs[2].id, "test/sample.md")         // Jan 1
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func test_applySortOrder_reloadsFromAPI() async {
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: TestFixtures.sampleDocuments, nextCursor: nil)
        )
        await sut.loadDocuments()
        mockAPIClient.reset()
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: TestFixtures.sampleDocuments, nextCursor: nil)
        )
        sut.sortOrder = .createdDate
        await sut.applySortOrder()
        XCTAssertEqual(mockAPIClient.listDocumentsCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastListDocumentsSort, .createdDate)
    }

    func test_applySortOrder_passesModifiedSortToAPI() async {
        mockAPIClient.listDocumentsResult = .success(DocumentListResponse(documents: [], nextCursor: nil))
        await sut.loadDocuments()
        XCTAssertEqual(mockAPIClient.lastListDocumentsSort, .modifiedDate)
    }

    // MARK: - Search

    func test_search_shortQuery_remainsIdle() async {
        sut.searchText = "a"
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(sut.searchState, .idle)
        XCTAssertEqual(mockAPIClient.searchCallCount, 0)
    }

    func test_search_emptyQuery_remainsIdle() async {
        sut.searchText = ""
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(sut.searchState, .idle)
    }

    func test_search_whitespaceOnlyQuery_remainsIdle() async {
        sut.searchText = "  "
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(sut.searchState, .idle)
    }

    func test_search_validQuery_returnsResults() async {
        mockAPIClient.searchResult = .success(TestFixtures.sampleDocuments)
        sut.searchText = "sample"
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(sut.searchState, .loaded(TestFixtures.sampleDocuments))
        XCTAssertEqual(mockAPIClient.searchCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastSearchQuery, "sample")
    }

    func test_search_validQuery_emptyResults_showsEmpty() async {
        mockAPIClient.searchResult = .success([])
        sut.searchText = "nonexistent"
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(sut.searchState, .empty)
    }

    func test_search_error_showsError() async {
        mockAPIClient.searchResult = .failure(APIError.networkError)
        sut.searchText = "test query"
        try? await Task.sleep(for: .milliseconds(400))
        if case .error = sut.searchState { } else { XCTFail("Expected search error state") }
    }

    func test_search_rapidTyping_onlySendsOneRequest() async {
        mockAPIClient.searchResult = .success(TestFixtures.sampleDocuments)
        sut.searchText = "te"
        sut.searchText = "tes"
        sut.searchText = "test"
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(mockAPIClient.searchCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastSearchQuery, "test")
    }

    func test_search_directSearch_skipsDebounce() async {
        mockAPIClient.searchResult = .success(TestFixtures.sampleDocuments)
        sut.searchText = "direct"
        await sut.search()
        XCTAssertEqual(sut.searchState, .loaded(TestFixtures.sampleDocuments))
    }

    func test_search_directSearch_shortQuery_goesIdle() async {
        sut.searchText = "a"
        await sut.search()
        XCTAssertEqual(sut.searchState, .idle)
    }

    func test_search_semanticMode_passesMode() async {
        mockAPIClient.searchResult = .success(TestFixtures.sampleDocuments)
        sut.searchMode = .semantic
        sut.searchText = "sample"
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(mockAPIClient.lastSearchMode, .semantic)
    }

    func test_search_changingMode_retriggersSearch() async {
        mockAPIClient.searchResult = .success(TestFixtures.sampleDocuments)
        sut.searchText = "test query"
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(mockAPIClient.searchCallCount, 1)
        sut.searchMode = .semantic
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(mockAPIClient.searchCallCount, 2)
        XCTAssertEqual(mockAPIClient.lastSearchMode, .semantic)
    }

    func test_search_isSearchActive() {
        sut.searchText = "ab"
        XCTAssertTrue(sut.isSearchActive)
        sut.searchText = "a"
        XCTAssertFalse(sut.isSearchActive)
    }

    // MARK: - Search State Equality

    func test_searchState_equality() {
        let docs = TestFixtures.sampleDocuments
        XCTAssertEqual(
            DocumentListViewModel.SearchState.loaded(docs),
            DocumentListViewModel.SearchState.loaded(docs)
        )
        XCTAssertEqual(
            DocumentListViewModel.SearchState.error(APIError.networkError),
            DocumentListViewModel.SearchState.error(APIError.networkError)
        )
        XCTAssertNotEqual(DocumentListViewModel.SearchState.idle, DocumentListViewModel.SearchState.loading)
        XCTAssertNotEqual(DocumentListViewModel.SearchState.idle, DocumentListViewModel.SearchState.empty)
    }

    // MARK: - Tags

    func test_loadTags_success_sortsByCountDescending() async {
        mockAPIClient.listTagsResult = .success(TestFixtures.sampleTags)
        await sut.loadTags()
        XCTAssertEqual(sut.tags.count, 4)
        XCTAssertEqual(sut.tags[0].name, "meeting")   // 10
        XCTAssertEqual(sut.tags[1].name, "project")    // 7
        XCTAssertEqual(sut.tags[2].name, "test")       // 5
        XCTAssertEqual(sut.tags[3].name, "idea")       // 3
        XCTAssertEqual(mockAPIClient.listTagsCallCount, 1)
    }

    func test_loadTags_emptyResult_keepsEmptyArray() async {
        mockAPIClient.listTagsResult = .success([])
        await sut.loadTags()
        XCTAssertTrue(sut.tags.isEmpty)
    }

    func test_loadTags_error_keepsEmptyArray() async {
        mockAPIClient.listTagsResult = .failure(APIError.networkError)
        await sut.loadTags()
        XCTAssertTrue(sut.tags.isEmpty)
    }

    // MARK: - Tag Filter

    func test_loadDocuments_withTag_fetchesByTag() async {
        sut.selectedTag = TestFixtures.sampleTag
        mockAPIClient.documentsByTagResult = .success(TestFixtures.sampleDocuments)
        await sut.loadDocuments()

        XCTAssertEqual(mockAPIClient.documentsByTagCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastDocumentsByTagTag, "test")
        XCTAssertEqual(mockAPIClient.lastDocumentsByTagLimit, 50)
        XCTAssertEqual(mockAPIClient.listDocumentsCallCount, 0)
        if case .loaded(let documents) = sut.state {
            XCTAssertEqual(documents.count, 3)
            XCTAssertEqual(documents[0].id, "ideas/new-feature.md")
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
    }

    func test_loadDocuments_withTag_emptyResult_showsEmpty() async {
        sut.selectedTag = TestFixtures.sampleTag
        mockAPIClient.documentsByTagResult = .success([])
        await sut.loadDocuments()
        XCTAssertEqual(sut.state, .empty)
    }

    func test_loadDocuments_withTag_error_showsError() async {
        sut.selectedTag = TestFixtures.sampleTag
        mockAPIClient.documentsByTagResult = .failure(APIError.networkError)
        await sut.loadDocuments()
        if case .error = sut.state { } else { XCTFail("Expected error state") }
    }

    func test_loadDocuments_withTag_disablesPagination() async {
        sut.selectedTag = TestFixtures.sampleTag
        mockAPIClient.documentsByTagResult = .success(TestFixtures.sampleDocuments)
        await sut.loadDocuments()
        XCTAssertFalse(sut.hasMorePages)
    }

    func test_loadDocuments_withTag_cancellationError_doesNotSetErrorState() async {
        sut.selectedTag = TestFixtures.sampleTag
        mockAPIClient.documentsByTagResult = .failure(CancellationError())
        await sut.loadDocuments()
        if case .error = sut.state { XCTFail("CancellationError should not produce error state") }
    }

    // MARK: - Tag + Classification Combined Filter

    func test_loadDocuments_withTagAndClassification_filtersClientSide() async {
        sut.selectedTag = TestFixtures.sampleTag
        sut.selectedClassification = .meeting
        mockAPIClient.documentsByTagResult = .success(TestFixtures.sampleDocuments)
        await sut.loadDocuments()

        if case .loaded(let documents) = sut.state {
            XCTAssertEqual(documents.count, 1)
            XCTAssertEqual(documents[0].id, "meetings/weekly.md")
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
    }

    func test_loadDocuments_withTagAndClassification_noMatches_showsEmpty() async {
        sut.selectedTag = TestFixtures.sampleTag
        sut.selectedClassification = .meeting
        mockAPIClient.documentsByTagResult = .success([TestFixtures.sampleDocument])
        await sut.loadDocuments()
        XCTAssertEqual(sut.state, .empty)
    }

    // MARK: - hasActiveFilter

    func test_hasActiveFilter() {
        XCTAssertFalse(sut.hasActiveFilter)
        sut.selectedClassification = .meeting
        XCTAssertTrue(sut.hasActiveFilter)
        sut.selectedClassification = nil
        sut.selectedTag = TestFixtures.sampleTag
        XCTAssertTrue(sut.hasActiveFilter)
        sut.selectedClassification = .meeting
        XCTAssertTrue(sut.hasActiveFilter)
    }
}
