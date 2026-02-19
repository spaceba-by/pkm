import XCTest
@testable import PKMReader

@MainActor
final class DocumentEditorViewModelTests: XCTestCase {
    private var mockAPIClient: MockAPIClient!  // swiftlint:disable:this implicitly_unwrapped_optional

    override func setUp() async throws {
        mockAPIClient = MockAPIClient()
    }

    override func tearDown() async throws {
        mockAPIClient = nil
    }

    // MARK: - Helpers

    private func makeDocument(
        id: String = "notes/test.md",
        title: String = "Test Doc",
        content: String = "# Hello"
    ) -> Document {
        Document(
            id: id,
            title: title,
            content: content,
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
    }

    // MARK: - Create Mode

    func test_createMode_initialState() {
        let sut = DocumentEditorViewModel(mode: .create, apiClient: mockAPIClient)

        XCTAssertEqual(sut.content, "")
        XCTAssertEqual(sut.documentKey, "")
        XCTAssertEqual(sut.title, "")
        XCTAssertEqual(sut.saveState, .idle)
        XCTAssertFalse(sut.showPreview)
        XCTAssertEqual(sut.navigationTitle, "New Document")
    }

    func test_createMode_isValid_requiresMdExtension() {
        let sut = DocumentEditorViewModel(mode: .create, apiClient: mockAPIClient)

        sut.documentKey = "test"
        XCTAssertFalse(sut.isValid)

        sut.documentKey = "test.md"
        XCTAssertTrue(sut.isValid)
    }

    func test_createMode_isValid_requiresNonEmpty() {
        let sut = DocumentEditorViewModel(mode: .create, apiClient: mockAPIClient)

        sut.documentKey = ""
        XCTAssertFalse(sut.isValid)

        sut.documentKey = "   "
        XCTAssertFalse(sut.isValid)
    }

    func test_createMode_save_success() async {
        let sut = DocumentEditorViewModel(mode: .create, apiClient: mockAPIClient)
        sut.documentKey = "notes/new.md"
        sut.title = "New Note"
        sut.content = "# Content"

        await sut.save()

        XCTAssertEqual(sut.saveState, .saved)
        XCTAssertEqual(mockAPIClient.createDocumentCallCount, 1)
    }

    func test_createMode_save_withoutTitle() async {
        let sut = DocumentEditorViewModel(mode: .create, apiClient: mockAPIClient)
        sut.documentKey = "notes/new.md"
        sut.title = ""
        sut.content = "# Content"

        await sut.save()

        XCTAssertEqual(sut.saveState, .saved)
    }

    func test_createMode_save_invalidKey_doesNothing() async {
        let sut = DocumentEditorViewModel(mode: .create, apiClient: mockAPIClient)
        sut.documentKey = ""

        await sut.save()

        XCTAssertEqual(sut.saveState, .idle)
        XCTAssertEqual(mockAPIClient.createDocumentCallCount, 0)
    }

    func test_createMode_save_failure() async {
        mockAPIClient.createDocumentResult = .failure(APIError.networkError)
        let sut = DocumentEditorViewModel(mode: .create, apiClient: mockAPIClient)
        sut.documentKey = "notes/new.md"
        sut.content = "# Content"

        await sut.save()

        if case .error = sut.saveState {
            // Expected
        } else {
            XCTFail("Expected error state")
        }
    }

    func test_createMode_save_conflictError() async {
        mockAPIClient.createDocumentResult = .failure(APIError.httpError(statusCode: 409))
        let sut = DocumentEditorViewModel(mode: .create, apiClient: mockAPIClient)
        sut.documentKey = "notes/new.md"
        sut.content = "# Content"

        await sut.save()

        XCTAssertEqual(sut.saveState, .error("This document was modified elsewhere. Please reload and try again."))
    }

    func test_createMode_save_forbiddenError() async {
        mockAPIClient.createDocumentResult = .failure(APIError.httpError(statusCode: 403))
        let sut = DocumentEditorViewModel(mode: .create, apiClient: mockAPIClient)
        sut.documentKey = "notes/new.md"
        sut.content = "# Content"

        await sut.save()

        XCTAssertEqual(sut.saveState, .error("Admin access required to save documents."))
    }

    // MARK: - Edit Mode

    func test_editMode_initialState() {
        let doc = makeDocument()
        let sut = DocumentEditorViewModel(mode: .edit(doc), apiClient: mockAPIClient)

        XCTAssertEqual(sut.content, "# Hello")
        XCTAssertEqual(sut.documentKey, "notes/test.md")
        XCTAssertEqual(sut.title, "Test Doc")
        XCTAssertEqual(sut.navigationTitle, "Edit Document")
    }

    func test_editMode_isAlwaysValid() {
        let doc = makeDocument()
        let sut = DocumentEditorViewModel(mode: .edit(doc), apiClient: mockAPIClient)

        XCTAssertTrue(sut.isValid)
    }

    func test_editMode_save_success() async {
        let doc = makeDocument()
        let sut = DocumentEditorViewModel(mode: .edit(doc), apiClient: mockAPIClient)
        sut.content = "# Updated"

        await sut.save()

        XCTAssertEqual(sut.saveState, .saved)
        XCTAssertEqual(mockAPIClient.updateDocumentCallCount, 1)
    }

    func test_editMode_save_failure() async {
        mockAPIClient.updateDocumentResult = .failure(APIError.networkError)
        let doc = makeDocument()
        let sut = DocumentEditorViewModel(mode: .edit(doc), apiClient: mockAPIClient)

        await sut.save()

        if case .error = sut.saveState {
            // Expected
        } else {
            XCTFail("Expected error state")
        }
    }

    // MARK: - Save State

    func test_resetSaveState() {
        let sut = DocumentEditorViewModel(mode: .create, apiClient: mockAPIClient)
        sut.resetSaveState()
        XCTAssertEqual(sut.saveState, .idle)
    }

    func test_saveState_equatable() {
        XCTAssertEqual(DocumentEditorViewModel.SaveState.idle, .idle)
        XCTAssertEqual(DocumentEditorViewModel.SaveState.saving, .saving)
        XCTAssertEqual(DocumentEditorViewModel.SaveState.saved, .saved)
        XCTAssertEqual(DocumentEditorViewModel.SaveState.error("a"), .error("a"))
        XCTAssertNotEqual(DocumentEditorViewModel.SaveState.error("a"), .error("b"))
        XCTAssertNotEqual(DocumentEditorViewModel.SaveState.idle, .saving)
    }

    // MARK: - Mode Equatable

    func test_mode_equatable() {
        let doc = makeDocument()
        XCTAssertEqual(DocumentEditorViewModel.Mode.create, .create)
        XCTAssertEqual(DocumentEditorViewModel.Mode.edit(doc), .edit(doc))
        XCTAssertNotEqual(DocumentEditorViewModel.Mode.create, .edit(doc))
    }

    // MARK: - Preview Toggle

    func test_showPreview_toggle() {
        let sut = DocumentEditorViewModel(mode: .create, apiClient: mockAPIClient)
        XCTAssertFalse(sut.showPreview)
        sut.showPreview = true
        XCTAssertTrue(sut.showPreview)
    }
}
