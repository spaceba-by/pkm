import XCTest

/// Page object for the Search screen
final class SearchPage {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var searchView: XCUIElement {
        app.otherElements["SearchView"].firstMatch
    }

    var searchField: XCUIElement {
        app.searchFields.firstMatch
    }

    var resultsList: XCUIElement {
        app.collectionViews["SearchResultsList"].firstMatch
    }

    var emptyStateView: XCUIElement {
        app.staticTexts["No Results"].firstMatch
    }

    var idleStateView: XCUIElement {
        app.staticTexts["Search Documents"].firstMatch
    }

    // MARK: - Actions

    func search(for query: String) {
        searchField.tap()
        searchField.typeText(query)
    }

    func tapResult(at index: Int) {
        resultsList.cells.element(boundBy: index).tap()
    }

    // MARK: - Assertions

    func assertIsDisplayed(timeout: TimeInterval = 5) {
        XCTAssertTrue(searchView.waitForExistence(timeout: timeout), "Search screen not displayed")
    }

    func assertShowsIdleState(timeout: TimeInterval = 5) {
        XCTAssertTrue(idleStateView.waitForExistence(timeout: timeout))
    }

    func assertShowsEmptyState(timeout: TimeInterval = 5) {
        XCTAssertTrue(emptyStateView.waitForExistence(timeout: timeout))
    }
}
