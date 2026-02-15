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

    // MARK: - Classification

    func test_initialClassification_matchesDocument() {
        let document = TestFixtures.sampleMeetingDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)
        XCTAssertEqual(sut.classification, .meeting)
    }

    func test_updateClassification_success_updatesValue() async {
        let document = TestFixtures.sampleDocument // .reference
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)
        mockAPIClient.updateClassificationResult = .success(())

        await sut.updateClassification(to: .idea)

        XCTAssertEqual(sut.classification, .idea)
        XCTAssertNil(sut.classificationUpdateError)
        XCTAssertFalse(sut.isUpdatingClassification)
    }

    func test_updateClassification_sameValue_doesNothing() async {
        let document = TestFixtures.sampleDocument // .reference
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        await sut.updateClassification(to: .reference)

        XCTAssertEqual(mockAPIClient.updateClassificationCallCount, 0)
    }

    func test_updateClassification_failure_setsError() async {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)
        mockAPIClient.updateClassificationResult = .failure(APIError.networkError)

        await sut.updateClassification(to: .meeting)

        // Classification should NOT change on failure
        XCTAssertEqual(sut.classification, .reference)
        XCTAssertNotNil(sut.classificationUpdateError)
        XCTAssertFalse(sut.isUpdatingClassification)
    }

    func test_updateClassification_callsAPIWithCorrectParams() async {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)
        mockAPIClient.updateClassificationResult = .success(())

        await sut.updateClassification(to: .project)

        XCTAssertEqual(mockAPIClient.updateClassificationCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastUpdateClassificationDocumentId, document.id)
        XCTAssertEqual(mockAPIClient.lastUpdateClassificationValue, .project)
    }

    // MARK: - Content Placeholder

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
