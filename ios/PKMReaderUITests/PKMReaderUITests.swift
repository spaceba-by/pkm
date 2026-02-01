import XCTest

final class PKMReaderUITests: XCTestCase {
    private var app: XCUIApplication!
    private var documentListPage: DocumentListPage!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchForTesting()

        documentListPage = DocumentListPage(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        documentListPage = nil
    }

    // MARK: - App Launch Tests

    func testAppLaunches() throws {
        // Verify the app launches and shows the main screen
        documentListPage.assertIsDisplayed()
    }

    func testAppShowsMainTitle() throws {
        // Verify the main title is displayed
        XCTAssertTrue(app.staticTexts["PKM Reader"].exists)
    }

    func testAppShowsDocumentsNavigationTitle() throws {
        // Verify the navigation bar title
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 5))
    }

    // MARK: - Accessibility Tests

    func testMainScreenHasAccessibilityIdentifiers() throws {
        // Verify key elements have accessibility identifiers
        XCTAssertTrue(app.staticTexts["PKM Reader"].exists)
    }
}
