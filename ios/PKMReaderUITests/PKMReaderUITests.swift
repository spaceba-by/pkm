import XCTest

final class PKMReaderUITests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var app: XCUIApplication!
    private var loginPage: LoginPage!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchLoggedOut()
        loginPage = LoginPage(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        loginPage = nil
    }

    // MARK: - App Launch Tests

    func testAppLaunches() {
        // Verify the app launches and shows the login screen (unauthenticated state)
        loginPage.assertIsDisplayed()
    }

    func testAppShowsMainTitle() {
        // Verify the main title is displayed on the login screen
        XCTAssertTrue(app.staticTexts["PKM Reader"].waitForExistence(timeout: 5))
    }

    func testAppShowsLoginScreen() {
        // Verify the login screen elements are present
        loginPage.assertAllElementsExist()
    }

    // MARK: - Accessibility Tests

    func testMainScreenHasAccessibilityIdentifiers() {
        // Verify key elements have accessibility identifiers
        // Wait for the first element to ensure the screen is loaded
        XCTAssertTrue(app.staticTexts["PKM Reader"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["EmailField"].exists)
        XCTAssertTrue(app.secureTextFields["PasswordField"].exists)
        XCTAssertTrue(app.buttons["SignInButton"].exists)
    }
}
