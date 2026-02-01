import XCTest

@MainActor
final class PKMReaderUITests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private nonisolated(unsafe) var app: XCUIApplication!
    private nonisolated(unsafe) var documentListPage: DocumentListPage!
    // swiftlint:enable implicitly_unwrapped_optional

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
