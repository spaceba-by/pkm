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

    // MARK: - Content Processing

    func test_processContent_stripsFrontmatter() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        let content = "---\ntitle: Test\ntags: [a, b]\n---\n# Hello\n\nBody text"
        let result = sut.processContent(content)
        XCTAssertEqual(result, "# Hello\n\nBody text")
    }

    func test_processContent_noFrontmatter_passesThrough() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        let content = "# No Front Matter\n\nJust content."
        let result = sut.processContent(content)
        XCTAssertEqual(result, "# No Front Matter\n\nJust content.")
    }

    func test_processContent_emptyFrontmatter() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        let content = "---\n---\n# After empty front matter"
        let result = sut.processContent(content)
        XCTAssertEqual(result, "# After empty front matter")
    }

    func test_processContent_frontmatterWithSpecialChars() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        let content = "---\ntitle: \"Test: Special & Chars\"\ndescription: 'It\\'s a test'\n---\n# Content"
        let result = sut.processContent(content)
        XCTAssertEqual(result, "# Content")
    }

    func test_processContent_uncheckedCheckboxes() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        let content = "- [ ] Todo item\n- [ ] Another item"
        let result = sut.processContent(content)
        XCTAssertEqual(result, "- ☐ Todo item\n- ☐ Another item")
    }

    func test_processContent_checkedCheckboxes() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        let content = "- [x] Done item\n- [X] Also done"
        let result = sut.processContent(content)
        XCTAssertEqual(result, "- ☑ Done item\n- ☑ Also done")
    }

    func test_processContent_mixedCheckboxes() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        let content = "- [x] Done\n- [ ] Not done\n- [X] Also done"
        let result = sut.processContent(content)
        XCTAssertEqual(result, "- ☑ Done\n- ☐ Not done\n- ☑ Also done")
    }

    func test_processContent_nestedCheckboxes() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        let content = "- [x] Parent\n  - [ ] Child\n    - [x] Grandchild"
        let result = sut.processContent(content)
        XCTAssertEqual(result, "- ☑ Parent\n  - ☐ Child\n    - ☑ Grandchild")
    }

    func test_processContent_simpleWikilink() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        let content = "See [[My Page]] for details"
        let result = sut.processContent(content)
        XCTAssertEqual(result, "See [My Page](pkm:My%20Page) for details")
    }

    func test_processContent_wikilinkWithDisplayText() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        let content = "See [[target-page|Display Text]] here"
        let result = sut.processContent(content)
        XCTAssertEqual(result, "See [Display Text](pkm:target-page) here")
    }

    func test_processContent_multipleWikilinks() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        let content = "Link to [[PageA]] and [[PageB|Page B]]"
        let result = sut.processContent(content)
        XCTAssertEqual(result, "Link to [PageA](pkm:PageA) and [Page B](pkm:PageB)")
    }

    func test_processContent_allTransformations() {
        let document = TestFixtures.sampleDocument
        sut = DocumentDetailViewModel(document: document, apiClient: mockAPIClient)

        let content = "---\ntitle: Test\n---\n# Tasks\n\n- [x] Read [[Documentation]]\n- [ ] Review [[Code|the code]]"
        let result = sut.processContent(content)
        XCTAssertEqual(
            result,
            "# Tasks\n\n- ☑ Read [Documentation](pkm:Documentation)\n- ☐ Review [the code](pkm:Code)"
        )
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
