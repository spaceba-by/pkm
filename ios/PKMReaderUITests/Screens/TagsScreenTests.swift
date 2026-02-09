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

        let tagsList = tagsPage.tagsList
        XCTAssertTrue(tagsList.waitForExistence(timeout: 5), "Tags list not displayed")

        // Tap the first tag
        tagsPage.tapTag(at: 0)

        // Verify navigation to tag documents view
        let tagDocumentsView = app.otherElements["TagDocumentsView"]
        XCTAssertTrue(tagDocumentsView.waitForExistence(timeout: 5), "Tag documents view not displayed")
    }

    func test_tapDocument_navigatesToDetail() throws {
        tagsPage.assertIsDisplayed()

        let tagsList = tagsPage.tagsList
        XCTAssertTrue(tagsList.waitForExistence(timeout: 5), "Tags list not displayed")

        // Tap the "meeting" tag which has associated documents
        tagsPage.tapTag(named: "meeting")

        // Wait for documents list to appear
        let tagDocumentsView = app.otherElements["TagDocumentsView"]
        XCTAssertTrue(tagDocumentsView.waitForExistence(timeout: 5), "Tag documents view not displayed")

        // Tap the first document in the list
        let documentsList = app.collectionViews["TagDocumentsList"]
        XCTAssertTrue(documentsList.waitForExistence(timeout: 5), "Documents list not displayed")
        documentsList.cells.element(boundBy: 0).tap()

        // Verify navigation to document detail
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Document detail not displayed")
    }

    // MARK: - Pull to Refresh

    func test_pullToRefresh_reloadsTags() throws {
        tagsPage.assertIsDisplayed()

        let tagsList = tagsPage.tagsList
        XCTAssertTrue(tagsList.waitForExistence(timeout: 5), "Tags list not displayed")

        // Pull down to refresh
        let firstCell = tagsList.cells.element(boundBy: 0)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5))
        firstCell.swipeDown()

        // After refresh, tags list should still be displayed
        XCTAssertTrue(tagsList.waitForExistence(timeout: 5), "Tags list not displayed after refresh")
    }
}
