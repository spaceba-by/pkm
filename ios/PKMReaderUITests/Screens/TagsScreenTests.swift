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

        // Coordinate tap on first cell to reliably trigger NavigationLink
        let firstCell = tagsList.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "Tag cell not found")
        firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Verify navigation to tag documents view
        let tagDocumentsView = app.otherElements["TagDocumentsView"]
        XCTAssertTrue(tagDocumentsView.waitForExistence(timeout: 5), "Tag documents view not displayed")
    }

    func test_tapDocument_navigatesToDetail() throws {
        tagsPage.assertIsDisplayed()

        let tagsList = tagsPage.tagsList
        XCTAssertTrue(tagsList.waitForExistence(timeout: 5), "Tags list not displayed")

        // Tap the first tag cell
        let firstCell = tagsList.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "Tag cell not found")
        firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Wait for tag documents view
        let tagDocumentsView = app.otherElements["TagDocumentsView"]
        XCTAssertTrue(tagDocumentsView.waitForExistence(timeout: 5), "Tag documents view not displayed")

        // Tap the first document cell
        let docList = app.collectionViews["TagDocumentsList"]
        XCTAssertTrue(docList.waitForExistence(timeout: 5), "Tag documents list not displayed")

        let docCell = docList.cells.firstMatch
        XCTAssertTrue(docCell.waitForExistence(timeout: 5), "Document cell not found")
        docCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Verify navigation to document detail
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Document detail not displayed")
    }

    // MARK: - Pull to Refresh

    func test_pullToRefresh_reloadsTags() throws {
        tagsPage.assertIsDisplayed()

        let tagsList = tagsPage.tagsList
        XCTAssertTrue(tagsList.waitForExistence(timeout: 5), "Tags list not displayed")

        // Swipe down on the list to trigger pull-to-refresh
        tagsList.swipeDown()

        // After refresh, tags list should still be displayed
        XCTAssertTrue(tagsList.waitForExistence(timeout: 5), "Tags list not displayed after refresh")
    }
}
