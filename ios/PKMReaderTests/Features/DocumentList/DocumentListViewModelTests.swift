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

    // MARK: - Initial State Tests

    func test_initialState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
    }

    func test_initialState_hasNoMorePages() {
        XCTAssertFalse(sut.hasMorePages)
    }

    func test_initialState_noSelectedClassification() {
        XCTAssertNil(sut.selectedClassification)
    }

    func test_initialState_emptySearchText() {
        XCTAssertEqual(sut.searchText, "")
    }

    func test_initialState_sortOrderIsModifiedDate() {
        XCTAssertEqual(sut.sortOrder, .modifiedDate)
    }

    // MARK: - Load Documents Tests

    func test_loadDocuments_success_updatesStateToLoaded() async {
        // Given
        let documents = TestFixtures.sampleDocuments
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: documents, nextCursor: nil)
        )

        // When
        await sut.loadDocuments()

        // Then
        if case .loaded(let loadedDocs) = sut.state {
            XCTAssertEqual(loadedDocs.count, documents.count)
            // Documents are sorted by modified date descending
            XCTAssertEqual(loadedDocs.first?.id, "ideas/new-feature.md")
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
    }

    func test_loadDocuments_emptyResult_updatesStateToEmpty() async {
        // Given
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [], nextCursor: nil)
        )

        // When
        await sut.loadDocuments()

        // Then
        XCTAssertEqual(sut.state, .empty)
    }

    func test_loadDocuments_failure_updatesStateToError() async {
        // Given
        mockAPIClient.listDocumentsResult = .failure(APIError.invalidResponse)

        // When
        await sut.loadDocuments()

        // Then
        if case .error = sut.state {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
    }

    func test_loadDocuments_callsAPIWithCorrectParameters() async {
        // Given
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [], nextCursor: nil)
        )

        // When
        await sut.loadDocuments()

        // Then
        XCTAssertEqual(mockAPIClient.listDocumentsCallCount, 1)
        XCTAssertNil(mockAPIClient.lastListDocumentsClassification)
        XCTAssertEqual(mockAPIClient.lastListDocumentsLimit, 50)
        XCTAssertNil(mockAPIClient.lastListDocumentsCursor)
    }

    // MARK: - Classification Filter Tests

    func test_loadDocuments_withClassification_passesFilterToAPI() async {
        // Given
        sut.selectedClassification = .meeting
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [], nextCursor: nil)
        )

        // When
        await sut.loadDocuments()

        // Then
        XCTAssertEqual(mockAPIClient.lastListDocumentsClassification, .meeting)
    }

    // MARK: - Pagination Tests

    func test_loadDocuments_withNextCursor_setsHasMorePages() async {
        // Given
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(
                documents: TestFixtures.sampleDocuments,
                nextCursor: "next-page-token"
            )
        )

        // When
        await sut.loadDocuments()

        // Then
        XCTAssertTrue(sut.hasMorePages)
    }

    func test_loadDocuments_withoutNextCursor_hasNoMorePages() async {
        // Given
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(
                documents: TestFixtures.sampleDocuments,
                nextCursor: nil
            )
        )

        // When
        await sut.loadDocuments()

        // Then
        XCTAssertFalse(sut.hasMorePages)
    }

    func test_loadNextPage_whenNoMorePages_doesNotCallAPI() async {
        // Given
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: TestFixtures.sampleDocuments, nextCursor: nil)
        )
        await sut.loadDocuments()
        mockAPIClient.reset()

        // When
        await sut.loadNextPage()

        // Then
        XCTAssertEqual(mockAPIClient.listDocumentsCallCount, 0)
    }

    func test_loadNextPage_appendsDocuments() async {
        // Given
        let firstPage = [TestFixtures.sampleDocument]
        let secondPage = [TestFixtures.sampleMeetingDocument]

        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: firstPage, nextCursor: "page2")
        )
        await sut.loadDocuments()

        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: secondPage, nextCursor: nil)
        )

        // When
        await sut.loadNextPage()

        // Then: both documents present, sorted by modified date descending
        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, 2)
            XCTAssertEqual(docs[0].id, secondPage[0].id)  // Jan 2 (newer)
            XCTAssertEqual(docs[1].id, firstPage[0].id)   // Jan 1 (older)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    // MARK: - Refresh Tests

    // MARK: - State Equality

    func test_state_loaded_equality() {
        let docs = TestFixtures.sampleDocuments
        XCTAssertEqual(
            DocumentListViewModel.State.loaded(docs),
            DocumentListViewModel.State.loaded(docs)
        )
    }

    func test_state_error_equality() {
        let state1 = DocumentListViewModel.State.error(APIError.networkError)
        let state2 = DocumentListViewModel.State.error(APIError.networkError)
        XCTAssertEqual(state1, state2)
    }

    func test_state_different_notEqual() {
        XCTAssertNotEqual(DocumentListViewModel.State.loading, DocumentListViewModel.State.empty)
        XCTAssertNotEqual(
            DocumentListViewModel.State.loaded(TestFixtures.sampleDocuments),
            DocumentListViewModel.State.empty
        )
    }

    // MARK: - Refresh

    func test_refresh_reloadsDocuments() async {
        // Given
        let initialDocs = [TestFixtures.sampleDocument]
        let refreshedDocs = TestFixtures.sampleDocuments

        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: initialDocs, nextCursor: nil)
        )
        await sut.loadDocuments()

        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: refreshedDocs, nextCursor: nil)
        )

        // When
        await sut.refresh()

        // Then
        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, refreshedDocs.count)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    // MARK: - CancellationError Handling

    func test_loadDocuments_cancellationError_doesNotSetErrorState() async {
        mockAPIClient.listDocumentsResult = .failure(CancellationError())
        await sut.loadDocuments()

        if case .error = sut.state {
            XCTFail("CancellationError should not produce error state")
        }
    }

    func test_refresh_cancellationError_keepsExistingState() async {
        // Given: loaded state
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: TestFixtures.sampleDocuments, nextCursor: nil)
        )
        await sut.loadDocuments()

        // When: refresh throws CancellationError
        mockAPIClient.listDocumentsResult = .failure(CancellationError())
        await sut.refresh()

        // Then: state remains loaded
        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, TestFixtures.sampleDocuments.count)
        } else {
            XCTFail("Expected loaded state preserved, got \(sut.state)")
        }
    }

    // MARK: - Pagination Error Handling

    func test_loadNextPage_error_stopsPageination() async {
        // Given: first page loaded with more pages
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [TestFixtures.sampleDocument], nextCursor: "page2")
        )
        await sut.loadDocuments()
        XCTAssertTrue(sut.hasMorePages)

        // When: next page fails
        mockAPIClient.listDocumentsResult = .failure(APIError.networkError)
        await sut.loadNextPage()

        // Then: pagination stops, existing docs preserved
        XCTAssertFalse(sut.hasMorePages)
        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, 1)
        } else {
            XCTFail("Expected loaded state preserved")
        }
    }

    func test_loadNextPage_cancellationError_doesNotStopPagination() async {
        // Given: first page loaded with more pages
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: [TestFixtures.sampleDocument], nextCursor: "page2")
        )
        await sut.loadDocuments()

        // When: next page is cancelled
        mockAPIClient.listDocumentsResult = .failure(CancellationError())
        await sut.loadNextPage()

        // Then: hasMorePages unchanged, existing docs preserved
        XCTAssertTrue(sut.hasMorePages)
        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, 1)
        } else {
            XCTFail("Expected loaded state preserved")
        }
    }

    // MARK: - Sort Order Tests

    func test_loadDocuments_sortsByModifiedDateDescending() async {
        // Given: documents in arbitrary order
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: TestFixtures.sampleDocuments, nextCursor: nil)
        )

        // When
        await sut.loadDocuments()

        // Then: sorted by modified date descending (most recent first)
        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs[0].id, "ideas/new-feature.md")   // Jan 3
            XCTAssertEqual(docs[1].id, "meetings/weekly.md")     // Jan 2
            XCTAssertEqual(docs[2].id, "test/sample.md")         // Jan 1
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func test_applySortOrder_resortsByCreatedDate() async {
        // Given: documents loaded with default modified sort
        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: TestFixtures.sampleDocuments, nextCursor: nil)
        )
        await sut.loadDocuments()

        // When: switch to created date sort
        sut.sortOrder = .createdDate
        sut.applySortOrder()

        // Then: sorted by created date descending (different order from modified sort)
        // Created dates: sample=Jan 3, meetings=Jan 2, ideas=Jan 1
        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs[0].id, "test/sample.md")         // Jan 3 created
            XCTAssertEqual(docs[1].id, "meetings/weekly.md")     // Jan 2 created
            XCTAssertEqual(docs[2].id, "ideas/new-feature.md")   // Jan 1 created
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func test_applySortOrder_whenNotLoaded_doesNothing() {
        // Given: loading state
        XCTAssertEqual(sut.state, .loading)

        // When
        sut.sortOrder = .createdDate
        sut.applySortOrder()

        // Then: state unchanged
        XCTAssertEqual(sut.state, .loading)
    }

    func test_loadNextPage_maintainsSortOrder() async {
        // Given: first page loaded
        let firstPage = [TestFixtures.sampleDocument] // Jan 1
        let secondPage = [TestFixtures.sampleIdeaDocument] // Jan 3

        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: firstPage, nextCursor: "page2")
        )
        await sut.loadDocuments()

        mockAPIClient.listDocumentsResult = .success(
            DocumentListResponse(documents: secondPage, nextCursor: nil)
        )

        // When
        await sut.loadNextPage()

        // Then: all documents sorted by modified date descending
        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, 2)
            XCTAssertEqual(docs[0].id, "ideas/new-feature.md")   // Jan 3
            XCTAssertEqual(docs[1].id, "test/sample.md")         // Jan 1
        } else {
            XCTFail("Expected loaded state")
        }
    }
}
