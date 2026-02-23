@testable import PKMReader
import XCTest

@MainActor
final class InsightDetailViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: InsightDetailViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
        sut = InsightDetailViewModel(key: "_agent/summaries/2024-01-01.md", apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_isLoading() {
        XCTAssertEqual(sut.contentState, .loading)
    }

    func test_key_isSetCorrectly() {
        XCTAssertEqual(sut.key, "_agent/summaries/2024-01-01.md")
    }

    // MARK: - Load Content Success

    func test_loadContent_success_showsLoadedWithContent() async {
        let document = TestFixtures.sampleDocument
        mockAPIClient.getDocumentResult = .success(document)

        await sut.loadContent()

        XCTAssertEqual(sut.contentState, .loaded("# Sample\n\nThis is a test document."))
        XCTAssertEqual(mockAPIClient.getDocumentCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastGetDocumentKey, "_agent/summaries/2024-01-01.md")
    }

    func test_loadContent_success_nilContent_showsFallbackMessage() async {
        let document = Document(
            id: "_agent/summaries/2024-01-01.md",
            title: "Summary",
            content: nil,
            metadata: DocumentMetadata(
                classification: .reference,
                tags: [],
                linksTo: [],
                entities: nil,
                created: Date(),
                modified: Date(),
                hasFrontmatter: false
            )
        )
        mockAPIClient.getDocumentResult = .success(document)

        await sut.loadContent()

        XCTAssertEqual(sut.contentState, .loaded("*No content available*"))
    }

    // MARK: - Load Content Error

    func test_loadContent_error_showsErrorState() async {
        mockAPIClient.getDocumentResult = .failure(APIError.networkError)

        await sut.loadContent()

        if case .error = sut.contentState {
            // Expected error state
        } else {
            XCTFail("Expected error state, got \(sut.contentState)")
        }
    }

    func test_loadContent_noResultConfigured_showsErrorState() async {
        // getDocumentResult defaults to nil, which throws APIError.invalidResponse
        await sut.loadContent()

        if case .error = sut.contentState {
            // Expected error state
        } else {
            XCTFail("Expected error state, got \(sut.contentState)")
        }
    }

    // MARK: - State Transitions

    func test_loadContent_alreadyLoaded_doesNotReload() async {
        let document = TestFixtures.sampleDocument
        mockAPIClient.getDocumentResult = .success(document)

        await sut.loadContent()
        XCTAssertEqual(mockAPIClient.getDocumentCallCount, 1)

        // Second call should be a no-op since content is already loaded
        await sut.loadContent()
        XCTAssertEqual(mockAPIClient.getDocumentCallCount, 1)
    }

    func test_loadContent_afterError_canRetry() async {
        // First attempt fails
        mockAPIClient.getDocumentResult = .failure(APIError.networkError)
        await sut.loadContent()

        if case .error = sut.contentState {
            // Expected
        } else {
            XCTFail("Expected error state after first attempt")
        }

        // Second attempt succeeds
        let document = TestFixtures.sampleDocument
        mockAPIClient.getDocumentResult = .success(document)
        await sut.loadContent()

        XCTAssertEqual(sut.contentState, .loaded("# Sample\n\nThis is a test document."))
        XCTAssertEqual(mockAPIClient.getDocumentCallCount, 2)
    }
}
