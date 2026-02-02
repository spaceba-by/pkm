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
            XCTAssertEqual(loadedDocs.first?.id, documents.first?.id)
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

        // Then
        if case .loaded(let docs) = sut.state {
            XCTAssertEqual(docs.count, 2)
            XCTAssertEqual(docs[0].id, firstPage[0].id)
            XCTAssertEqual(docs[1].id, secondPage[0].id)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    // MARK: - Refresh Tests

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
}
