import XCTest
@testable import PKMReader

@MainActor
final class TagDocumentsViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: TagDocumentsViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
        sut = TagDocumentsViewModel(
            tag: TestFixtures.sampleTag,
            apiClient: mockAPIClient
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
        XCTAssertEqual(sut.tag.name, "test")
    }

    // MARK: - Load Documents

    func test_loadDocuments_success_showsLoaded() async {
        mockAPIClient.documentsByTagResult = .success(TestFixtures.sampleDocuments)
        await sut.loadDocuments()

        if case .loaded(let documents) = sut.state {
            XCTAssertEqual(documents.count, 3)
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
        XCTAssertEqual(mockAPIClient.documentsByTagCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastDocumentsByTagTag, "test")
        XCTAssertEqual(mockAPIClient.lastDocumentsByTagLimit, 50)
    }

    func test_loadDocuments_emptyResult_showsEmpty() async {
        mockAPIClient.documentsByTagResult = .success([])
        await sut.loadDocuments()
        XCTAssertEqual(sut.state, .empty)
    }

    func test_loadDocuments_error_showsError() async {
        mockAPIClient.documentsByTagResult = .failure(APIError.networkError)
        await sut.loadDocuments()

        if case .error = sut.state {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
    }

    // MARK: - Refresh

    func test_refresh_reloadsData() async {
        mockAPIClient.documentsByTagResult = .success(TestFixtures.sampleDocuments)
        await sut.refresh()

        if case .loaded(let documents) = sut.state {
            XCTAssertEqual(documents.count, 3)
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
    }

    func test_refresh_keepsExistingDataVisible() async {
        // Given: loaded state
        mockAPIClient.documentsByTagResult = .success(TestFixtures.sampleDocuments)
        await sut.loadDocuments()

        // When: refresh is called
        mockAPIClient.documentsByTagResult = .success([TestFixtures.sampleDocument])
        await sut.refresh()

        // Then: state should never have been .loading (it stays loaded)
        if case .loaded(let documents) = sut.state {
            XCTAssertEqual(documents.count, 1)
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
    }

    // MARK: - CancellationError Handling

    func test_loadDocuments_cancellationError_doesNotSetErrorState() async {
        mockAPIClient.documentsByTagResult = .failure(CancellationError())
        await sut.loadDocuments()

        if case .error = sut.state {
            XCTFail("CancellationError should not produce error state")
        }
    }

    func test_refresh_cancellationError_keepsExistingState() async {
        // Given: loaded state
        mockAPIClient.documentsByTagResult = .success(TestFixtures.sampleDocuments)
        await sut.loadDocuments()

        // When: refresh throws CancellationError
        mockAPIClient.documentsByTagResult = .failure(CancellationError())
        await sut.refresh()

        // Then: state remains loaded (not error)
        if case .loaded(let documents) = sut.state {
            XCTAssertEqual(documents.count, 3)
        } else {
            XCTFail("Expected loaded state preserved, got \(sut.state)")
        }
    }
}
