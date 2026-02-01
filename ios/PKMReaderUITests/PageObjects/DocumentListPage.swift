@preconcurrency import XCTest

/// Page object for the Document List screen
@MainActor
final class DocumentListPage {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var navigationTitle: XCUIElement {
        app.navigationBars["Documents"].firstMatch
    }

    var documentList: XCUIElement {
        app.collectionViews.firstMatch
    }

    var filterButton: XCUIElement {
        app.buttons["Filter"].firstMatch
    }

    var searchField: XCUIElement {
        app.searchFields.firstMatch
    }

    var loadingIndicator: XCUIElement {
        app.activityIndicators.firstMatch
    }

    var emptyStateView: XCUIElement {
        app.staticTexts["No Documents"].firstMatch
    }

    var mainText: XCUIElement {
        app.staticTexts["PKM Reader"].firstMatch
    }

    func documentRow(at index: Int) -> XCUIElement {
        documentList.cells.element(boundBy: index)
    }

    func documentRow(withTitle title: String) -> XCUIElement {
        documentList.cells.containing(.staticText, identifier: title).firstMatch
    }

    // MARK: - Actions

    func tapDocument(at index: Int) {
        documentRow(at: index).tap()
    }

    func tapDocument(withTitle title: String) {
        documentRow(withTitle: title).tap()
    }

    func tapFilterButton() {
        filterButton.tap()
    }

    func search(for query: String) {
        searchField.tap()
        searchField.typeText(query)
    }

    func pullToRefresh() {
        documentList.swipeDown()
    }

    // MARK: - Assertions

    func assertIsDisplayed(timeout: TimeInterval = 5) {
        XCTAssertTrue(mainText.waitForExistence(timeout: timeout), "Document list screen not displayed")
    }

    func assertDocumentCount(_ count: Int) {
        XCTAssertEqual(documentList.cells.count, count)
    }

    func assertShowsEmptyState(timeout: TimeInterval = 5) {
        XCTAssertTrue(emptyStateView.waitForExistence(timeout: timeout))
    }

    func assertShowsLoading() {
        XCTAssertTrue(loadingIndicator.exists)
    }
}
