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

        // Verify navigation to tag documents view via back button presence
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Tag documents view not displayed")
    }

    func test_tapDocument_navigatesToDetail() throws {
        tagsPage.assertIsDisplayed()

        let tagsList = tagsPage.tagsList
        XCTAssertTrue(tagsList.waitForExistence(timeout: 5), "Tags list not displayed")

        // Tap the first tag cell
        let firstCell = tagsList.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "Tag cell not found")
        firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Wait for tag documents view via back button
        let navBackButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(navBackButton.waitForExistence(timeout: 5), "Tag documents view not displayed")

        // Wait for document cells to appear, then tap the first one
        let docCell = app.cells.firstMatch
        XCTAssertTrue(docCell.waitForExistence(timeout: 5), "Document cell not found")
        docCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Verify navigation to document detail - nav bar title should change
        let detailNavBar = app.navigationBars.element(boundBy: 0)
        XCTAssertTrue(detailNavBar.waitForExistence(timeout: 5), "Document detail not displayed")
        // Back button label changes from "Tags" to the tag name when pushed deeper
        XCTAssertFalse(detailNavBar.buttons.allElementsBoundByIndex.isEmpty, "Document detail navigation not displayed")
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
