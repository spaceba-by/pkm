import XCTest

/// Page object for the Tags screen
final class TagsPage {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var tagsView: XCUIElement {
        app.otherElements["TagsView"].firstMatch
    }

    var tagsList: XCUIElement {
        app.collectionViews["TagsList"].firstMatch
    }

    var emptyStateView: XCUIElement {
        app.staticTexts["No Tags"].firstMatch
    }

    // MARK: - Actions

    func tapTag(at index: Int) {
        tagsList.cells.element(boundBy: index).tap()
    }

    func tapTag(named name: String) {
        tagsList.cells.containing(.staticText, identifier: name).firstMatch.tap()
    }

    // MARK: - Assertions

    func assertIsDisplayed(timeout: TimeInterval = 5) {
        XCTAssertTrue(tagsView.waitForExistence(timeout: timeout), "Tags screen not displayed")
    }

    func assertShowsEmptyState(timeout: TimeInterval = 5) {
        XCTAssertTrue(emptyStateView.waitForExistence(timeout: timeout))
    }
}
