@testable import PKMReader
import XCTest

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

        if case let .loaded(content) = sut.contentState {
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

        if case let .loaded(content) = sut.contentState {
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

    // MARK: - Reload Content

    func test_reloadContent_forcesReloadWhenAlreadyLoaded() async {
        let document = TestFixtures.sampleDocument // has content, so starts in .loaded
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        // Verify it starts loaded
        if case .loaded = sut.contentState {} else {
            XCTFail("Expected loaded state initially")
        }

        let updatedDocument = Document(
            id: document.id,
            title: document.title,
            content: "# Updated Content",
            metadata: document.metadata
        )
        mockAPIClient.getDocumentResult = .success(updatedDocument)

        await sut.reloadContent()

        // Should have called the API despite already being loaded
        XCTAssertEqual(mockAPIClient.getDocumentCallCount, 1)
        if case let .loaded(content) = sut.contentState {
            XCTAssertTrue(content.contains("Updated Content"))
        } else {
            XCTFail("Expected loaded state after reload")
        }
        XCTAssertEqual(sut.rawContent, "# Updated Content")
    }

    func test_reloadContent_failure_updatesStateToError() async {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        mockAPIClient.getDocumentResult = .failure(APIError.networkError)

        await sut.reloadContent()

        if case .error = sut.contentState {} else {
            XCTFail("Expected error state after failed reload")
        }
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

    // MARK: - Content Processing

    func test_processContent_delegatesToMarkdownProcessor() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        let content = "---\ntitle: Test\n---\n# Tasks\n\n- [x] Read [[Documentation]]\n- [ ] Review [[Code|the code]]"
        let result = sut.processContent(content)
        XCTAssertEqual(result, MarkdownProcessor.process(content))
    }

    // MARK: - Raw Content for Editor

    func test_rawContent_setOnInit_whenContentPresent() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        XCTAssertEqual(sut.rawContent, document.content)
    }

    func test_rawContent_nilOnInit_whenContentNil() {
        let document = Document(
            id: "test.md",
            title: "Test",
            content: nil,
            metadata: TestFixtures.sampleDocument.metadata
        )
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        XCTAssertNil(sut.rawContent)
    }

    func test_rawContent_setAfterLoadContent() async {
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

        XCTAssertEqual(sut.rawContent, "# Full Content")
    }

    func test_documentWithContent_includesRawContent() async {
        let document = Document(
            id: "test.md",
            title: "Test",
            content: nil,
            metadata: TestFixtures.sampleDocument.metadata
        )
        let rawContent = "---\ntitle: Test\n---\n# Hello"
        let fullDocument = Document(
            id: "test.md",
            title: "Test",
            content: rawContent,
            metadata: TestFixtures.sampleDocument.metadata
        )

        mockAPIClient.getDocumentResult = .success(fullDocument)
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        await sut.loadContent()

        let docForEditor = sut.documentWithContent
        XCTAssertEqual(docForEditor.id, "test.md")
        XCTAssertEqual(docForEditor.content, rawContent)
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

        if case let .loaded(content) = sut.contentState {
            XCTAssertEqual(content, "*No content available*")
        } else {
            XCTFail("Expected loaded state with placeholder")
        }
        XCTAssertEqual(sut.rawContent, "")
    }

    func test_documentWithContent_returnsEmptyStringContent_whenDocumentHasNoContent() async {
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

        XCTAssertEqual(sut.documentWithContent.id, "test.md")
        XCTAssertEqual(sut.documentWithContent.content, "")
    }
}
