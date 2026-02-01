import XCTest

final class PKMReaderUITests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var app: XCUIApplication!
    private var documentListPage: DocumentListPage!
    // swiftlint:enable implicitly_unwrapped_optional

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchForTesting()
        documentListPage = DocumentListPage(app: app)
    }

    @MainActor
    override func tearDownWithError() throws {
        app = nil
        documentListPage = nil
    }

    // MARK: - App Launch Tests

    @MainActor
    func testAppLaunches() throws {
        // Verify the app launches and shows the main screen
        documentListPage.assertIsDisplayed()
    }

    @MainActor
    func testAppShowsMainTitle() throws {
        // Verify the main title is displayed
        XCTAssertTrue(app.staticTexts["PKM Reader"].exists)
    }

    @MainActor
    func testAppShowsDocumentsNavigationTitle() throws {
        // Verify the navigation bar title
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 5))
    }

    // MARK: - Accessibility Tests

    @MainActor
    func testMainScreenHasAccessibilityIdentifiers() throws {
        // Verify key elements have accessibility identifiers
        XCTAssertTrue(app.staticTexts["PKM Reader"].exists)
    }
}
