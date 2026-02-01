import XCTest

@MainActor
final class PKMReaderUITests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var app: XCUIApplication!
    private var documentListPage: DocumentListPage!
    // swiftlint:enable implicitly_unwrapped_optional

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchForTesting()

        documentListPage = DocumentListPage(app: app)
    }

    @MainActor
    override func tearDown() async throws {
        app = nil
        documentListPage = nil
        try await super.tearDown()
    }

    // MARK: - App Launch Tests

    func testAppLaunches() {
        // Verify the app launches and shows the main screen
        documentListPage.assertIsDisplayed()
    }

    func testAppShowsMainTitle() {
        // Verify the main title is displayed
        XCTAssertTrue(app.staticTexts["PKM Reader"].exists)
    }

    func testAppShowsDocumentsNavigationTitle() {
        // Verify the navigation bar title
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 5))
    }

    // MARK: - Accessibility Tests

    func testMainScreenHasAccessibilityIdentifiers() {
        // Verify key elements have accessibility identifiers
        XCTAssertTrue(app.staticTexts["PKM Reader"].exists)
    }
}
