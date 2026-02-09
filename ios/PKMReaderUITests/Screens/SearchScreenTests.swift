import XCTest

/// Search screen tests using mock API infrastructure
final class SearchScreenTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var app: XCUIApplication!
    private var searchPage: SearchPage!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchWithMockData()
        searchPage = SearchPage(app: app)

        // Navigate to Search tab
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab not found")
        searchTab.tap()
    }

    override func tearDownWithError() throws {
        app = nil
        searchPage = nil
    }

    // MARK: - Search Flow Tests

    func test_searchView_displaysIdleState() throws {
        searchPage.assertIsDisplayed()
        searchPage.assertShowsIdleState()
    }

    func test_search_showsResults() throws {
        searchPage.assertIsDisplayed()
        searchPage.search(for: "meeting")

        // Wait for debounced search results
        let resultsList = searchPage.resultsList
        XCTAssertTrue(resultsList.waitForExistence(timeout: 5), "Search results not displayed")
    }

    func test_tapResult_navigatesToDetail() throws {
        searchPage.assertIsDisplayed()
        searchPage.search(for: "meeting")

        let resultsList = searchPage.resultsList
        XCTAssertTrue(resultsList.waitForExistence(timeout: 5), "Search results not displayed")

        // Coordinate tap on first cell to reliably trigger NavigationLink
        let firstCell = resultsList.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "Search result cell not found")
        firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Verify navigation to detail view
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Detail view not displayed")
    }

    func test_search_noResults_showsEmptyState() throws {
        searchPage.assertIsDisplayed()
        searchPage.search(for: "zzzznonexistent")

        // Wait for empty state
        searchPage.assertShowsEmptyState(timeout: 5)
    }
}
