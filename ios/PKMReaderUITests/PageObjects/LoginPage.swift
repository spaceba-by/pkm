import XCTest

/// Page object for the Login screen
final class LoginPage {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var emailField: XCUIElement {
        app.textFields["EmailField"].firstMatch
    }

    var passwordField: XCUIElement {
        app.secureTextFields["PasswordField"].firstMatch
    }

    var signInButton: XCUIElement {
        app.buttons["SignInButton"].firstMatch
    }

    var errorMessage: XCUIElement {
        app.staticTexts["ErrorMessage"].firstMatch
    }

    var titleText: XCUIElement {
        app.staticTexts["PKM Reader"].firstMatch
    }

    var subtitleText: XCUIElement {
        app.staticTexts["Sign in to access your vault"].firstMatch
    }

    // MARK: - Actions

    /// Type email address into the email field
    func enterEmail(_ email: String) {
        emailField.tap()
        emailField.typeText(email)
    }

    /// Type password into the password field
    func enterPassword(_ password: String) {
        passwordField.tap()
        passwordField.typeText(password)
    }

    /// Tap the sign in button
    func tapSignIn() {
        signInButton.tap()
    }

    /// Complete the login flow with email and password
    func login(email: String, password: String) {
        enterEmail(email)
        enterPassword(password)
        tapSignIn()
    }

    /// Clear the email field
    func clearEmail() {
        emailField.tap()
        // Select all and delete
        emailField.doubleTap()
        if app.menuItems["Select All"].exists {
            app.menuItems["Select All"].tap()
        }
        emailField.typeText(XCUIKeyboardKey.delete.rawValue)
    }

    /// Clear the password field
    func clearPassword() {
        passwordField.tap()
        passwordField.doubleTap()
        if app.menuItems["Select All"].exists {
            app.menuItems["Select All"].tap()
        }
        passwordField.typeText(XCUIKeyboardKey.delete.rawValue)
    }

    // MARK: - Assertions

    /// Assert the login screen is displayed
    func assertIsDisplayed(timeout: TimeInterval = 5) {
        XCTAssertTrue(
            titleText.waitForExistence(timeout: timeout),
            "Login screen not displayed"
        )
    }

    /// Assert an error message is shown with specific text
    func assertErrorMessageShown(_ expectedMessage: String, timeout: TimeInterval = 5) {
        XCTAssertTrue(
            errorMessage.waitForExistence(timeout: timeout),
            "Error message not displayed"
        )
        XCTAssertEqual(
            errorMessage.label,
            expectedMessage,
            "Error message text mismatch"
        )
    }

    /// Assert the sign in button is enabled
    func assertSignInButtonEnabled() {
        XCTAssertTrue(signInButton.isEnabled, "Sign in button should be enabled")
    }

    /// Assert the sign in button is disabled
    func assertSignInButtonDisabled() {
        XCTAssertFalse(signInButton.isEnabled, "Sign in button should be disabled")
    }

    /// Assert all main UI elements are present
    func assertAllElementsExist(timeout: TimeInterval = 5) {
        XCTAssertTrue(
            titleText.waitForExistence(timeout: timeout),
            "Title 'PKM Reader' not found"
        )
        XCTAssertTrue(subtitleText.exists, "Subtitle not found")
        XCTAssertTrue(emailField.exists, "Email field not found")
        XCTAssertTrue(passwordField.exists, "Password field not found")
        XCTAssertTrue(signInButton.exists, "Sign in button not found")
    }
}
