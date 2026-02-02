import XCTest

final class PKMReaderUITests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var app: XCUIApplication!
    private var loginPage: LoginPage!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchForTesting()
        loginPage = LoginPage(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        loginPage = nil
    }

    // MARK: - App Launch Tests

    func testAppLaunches() throws {
        // Verify the app launches and shows the login screen (unauthenticated state)
        loginPage.assertIsDisplayed()
    }

    func testAppShowsMainTitle() throws {
        // Verify the main title is displayed on the login screen
        XCTAssertTrue(app.staticTexts["PKM Reader"].exists)
    }

    func testAppShowsLoginScreen() throws {
        // Verify the login screen elements are present
        loginPage.assertAllElementsExist()
    }

    // MARK: - Accessibility Tests

    func testMainScreenHasAccessibilityIdentifiers() throws {
        // Verify key elements have accessibility identifiers
        XCTAssertTrue(app.staticTexts["PKM Reader"].exists)
        XCTAssertTrue(app.textFields["EmailField"].exists)
        XCTAssertTrue(app.secureTextFields["PasswordField"].exists)
        XCTAssertTrue(app.buttons["SignInButton"].exists)
    }
}
