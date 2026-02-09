import XCTest

/// Tags screen tests using mock API infrastructure
final class TagsScreenTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var app: XCUIApplication!
    private var tagsPage: TagsPage!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchWithMockData()
        tagsPage = TagsPage(app: app)

        // Navigate to Tags tab
        let tagsTab = app.tabBars.buttons["Tags"]
        XCTAssertTrue(tagsTab.waitForExistence(timeout: 5), "Tags tab not found")
        tagsTab.tap()
    }

    override func tearDownWithError() throws {
        app = nil
        tagsPage = nil
    }

    // MARK: - Tags Flow Tests

    func test_tagsView_displaysList() throws {
        tagsPage.assertIsDisplayed()

        let tagsList = tagsPage.tagsList
        XCTAssertTrue(tagsList.waitForExistence(timeout: 5), "Tags list not displayed")
    }

    func test_tapTag_showsDocuments() throws {
        tagsPage.assertIsDisplayed()

        // Wait for a specific tag row to appear, then tap it
        let tagRow = app.buttons["TagRow_meeting"].firstMatch
        XCTAssertTrue(tagRow.waitForExistence(timeout: 5), "Tag row not found")
        tagRow.tap()

        // Verify navigation to tag documents view
        let tagDocumentsView = app.otherElements["TagDocumentsView"]
        XCTAssertTrue(tagDocumentsView.waitForExistence(timeout: 5), "Tag documents view not displayed")
    }

    func test_tapDocument_navigatesToDetail() throws {
        tagsPage.assertIsDisplayed()

        // Tap the "meeting" tag
        let tagRow = app.buttons["TagRow_meeting"].firstMatch
        XCTAssertTrue(tagRow.waitForExistence(timeout: 5), "Tag row not found")
        tagRow.tap()

        // Wait for tag documents view
        let tagDocumentsView = app.otherElements["TagDocumentsView"]
        XCTAssertTrue(tagDocumentsView.waitForExistence(timeout: 5), "Tag documents view not displayed")

        // Tap the first document by its accessibility identifier
        let documentRow = app.buttons["TagDocumentRow_notes/meeting-notes.md"].firstMatch
        XCTAssertTrue(documentRow.waitForExistence(timeout: 5), "Document row not found")
        documentRow.tap()

        // Verify navigation to document detail
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Document detail not displayed")
    }

    // MARK: - Pull to Refresh

    func test_pullToRefresh_reloadsTags() throws {
        tagsPage.assertIsDisplayed()

        let tagRow = app.buttons["TagRow_meeting"].firstMatch
        XCTAssertTrue(tagRow.waitForExistence(timeout: 5), "Tag row not found")
        tagRow.swipeDown()

        // After refresh, tags list should still be displayed
        let tagsList = tagsPage.tagsList
        XCTAssertTrue(tagsList.waitForExistence(timeout: 5), "Tags list not displayed after refresh")
    }
}
