import XCTest
@testable import PKMReader

@MainActor
final class DocumentDetailViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: DocumentDetailViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_withContent_isLoaded() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        if case .loaded(let content) = sut.contentState {
            XCTAssertEqual(content, document.content)
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func test_initialState_withoutContent_isLoading() {
        let document = Document(
            id: "test.md",
            title: "Test",
            content: nil,
            metadata: TestFixtures.sampleDocument.metadata
        )
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        XCTAssertEqual(sut.contentState, .loading)
    }

    // MARK: - Load Content

    func test_loadContent_success_updatesState() async {
        let document = Document(
            id: "test.md",
            title: "Test",
            content: nil,
            metadata: TestFixtures.sampleDocument.metadata
        )
        let fullDocument = Document(
            id: "test.md",
            title: "Test",
            content: "# Full Content",
            metadata: TestFixtures.sampleDocument.metadata
        )

        mockAPIClient.getDocumentResult = .success(fullDocument)
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        await sut.loadContent()

        if case .loaded(let content) = sut.contentState {
            XCTAssertEqual(content, "# Full Content")
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func test_loadContent_failure_updatesStateToError() async {
        let document = Document(
            id: "test.md",
            title: "Test",
            content: nil,
            metadata: TestFixtures.sampleDocument.metadata
        )

        mockAPIClient.getDocumentResult = .failure(APIError.networkError)
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        await sut.loadContent()

        if case .error = sut.contentState {
            // Expected
        } else {
            XCTFail("Expected error state")
        }
    }

    func test_loadContent_alreadyLoaded_doesNotReload() async {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        await sut.loadContent()

        XCTAssertEqual(mockAPIClient.getDocumentCallCount, 0)
    }

    func test_loadContent_documentWithNoContent_showsPlaceholder() async {
        let document = Document(
            id: "test.md",
            title: "Test",
            content: nil,
            metadata: TestFixtures.sampleDocument.metadata
        )
        let fullDocument = Document(
            id: "test.md",
            title: "Test",
            content: nil,
            metadata: TestFixtures.sampleDocument.metadata
        )

        mockAPIClient.getDocumentResult = .success(fullDocument)
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        await sut.loadContent()

        if case .loaded(let content) = sut.contentState {
            XCTAssertEqual(content, "*No content available*")
        } else {
            XCTFail("Expected loaded state with placeholder")
        }
    }
}
