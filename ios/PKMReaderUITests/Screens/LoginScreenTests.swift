import XCTest

final class LoginScreenTests: XCTestCase {
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

    // MARK: - Screen Display Tests

    func test_loginScreen_displaysCorrectly() throws {
        // Verify all UI elements are present on the login screen
        loginPage.assertAllElementsExist()
    }

    // MARK: - Form Validation Tests

    func test_signInButton_disabledWithEmptyFields() throws {
        // Sign in button should be disabled when both fields are empty
        loginPage.assertIsDisplayed()
        loginPage.assertSignInButtonDisabled()
    }

    func test_signInButton_disabledWithOnlyEmail() throws {
        // Sign in button should be disabled when only email is entered
        loginPage.enterEmail("test@example.com")
        loginPage.assertSignInButtonDisabled()
    }

    func test_signInButton_enabledWithValidInput() throws {
        // Sign in button should be enabled when both fields have input
        loginPage.enterEmail("test@example.com")
        loginPage.enterPassword("password123")
        loginPage.assertSignInButtonEnabled()
    }

    // MARK: - Input Field Tests

    func test_emailField_acceptsInput() throws {
        // Verify the email field accepts text input
        let testEmail = "user@example.com"
        loginPage.enterEmail(testEmail)

        XCTAssertEqual(loginPage.emailField.value as? String, testEmail)
    }

    func test_passwordField_acceptsInput() throws {
        // Verify the password field accepts text input
        // Note: Secure text fields show dots, so we verify by checking the field has content
        loginPage.enterPassword("secretpassword")

        // Password field value should not be empty
        let fieldValue = loginPage.passwordField.value as? String
        XCTAssertNotNil(fieldValue)
        // Secure fields typically show placeholder or bullets, not empty
        XCTAssertFalse(fieldValue?.isEmpty ?? true, "Password field should have content")
    }
}
