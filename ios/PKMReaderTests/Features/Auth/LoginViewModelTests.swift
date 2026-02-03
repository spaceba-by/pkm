import XCTest
@testable import PKMReader

@MainActor
final class LoginViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: LoginViewModel!
    private var mockAuthService: MockAuthService!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mockAuthService = MockAuthService()
        sut = LoginViewModel(authService: mockAuthService)
    }

    override func tearDown() async throws {
        sut = nil
        mockAuthService = nil
        try await super.tearDown()
    }

    // MARK: - Validation

    func test_isValid_withEmptyEmail_returnsFalse() {
        sut.email = ""
        sut.password = "password123"

        XCTAssertFalse(sut.isValid)
    }

    func test_isValid_withEmptyPassword_returnsFalse() {
        sut.email = "test@example.com"
        sut.password = ""

        XCTAssertFalse(sut.isValid)
    }

    func test_isValid_withInvalidEmail_returnsFalse() {
        sut.email = "notanemail"
        sut.password = "password123"

        XCTAssertFalse(sut.isValid)
    }

    func test_isValid_withValidCredentials_returnsTrue() {
        sut.email = "test@example.com"
        sut.password = "password123"

        XCTAssertTrue(sut.isValid)
    }

    func test_isValid_withWhitespaceOnlyEmail_returnsFalse() {
        sut.email = "   "
        sut.password = "password123"

        XCTAssertFalse(sut.isValid)
    }

    func test_isValid_withEmailWithWhitespace_trimsAndValidates() {
        sut.email = "  test@example.com  "
        sut.password = "password123"

        XCTAssertTrue(sut.isValid)
    }

    // MARK: - Sign In

    func test_signIn_success_clearsError() async {
        sut.email = "test@example.com"
        sut.password = "password123"
        mockAuthService.signInResult = .success(())

        await sut.signIn()

        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }

    func test_signIn_failure_setsError() async {
        sut.email = "test@example.com"
        sut.password = "wrongpassword"
        mockAuthService.signInResult = .failure(AuthError.invalidCredentials)

        await sut.signIn()

        XCTAssertNotNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }

    func test_signIn_invalidForm_doesNotCallService() async {
        sut.email = ""
        sut.password = "password123"

        await sut.signIn()

        XCTAssertEqual(mockAuthService.signInCallCount, 0)
    }

    func test_signIn_trimsEmailBeforeSending() async {
        sut.email = "  test@example.com  "
        sut.password = "password123"
        mockAuthService.signInResult = .success(())

        await sut.signIn()

        XCTAssertEqual(mockAuthService.lastSignInEmail, "test@example.com")
    }

    func test_signIn_accountNotConfirmed_setsAppropriateError() async {
        sut.email = "test@example.com"
        sut.password = "password123"
        mockAuthService.signInResult = .failure(AuthError.accountNotConfirmed)

        await sut.signIn()

        XCTAssertNotNil(sut.error)
        XCTAssertTrue(sut.error?.contains("confirm") ?? false)
    }

    func test_signIn_unknownError_setsGenericError() async {
        sut.email = "test@example.com"
        sut.password = "password123"

        struct TestError: Error {}
        mockAuthService.signInResult = .failure(TestError())

        await sut.signIn()

        XCTAssertEqual(sut.error, "An unexpected error occurred")
    }

    func test_signIn_isLoadingDuringRequest() async {
        sut.email = "test@example.com"
        sut.password = "password123"
        mockAuthService.signInDelay = 0.1
        mockAuthService.signInResult = .success(())

        // Start sign in without awaiting
        let task = Task {
            await sut.signIn()
        }

        // Brief delay to let the task start
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        XCTAssertTrue(sut.isLoading)

        // Wait for completion
        await task.value

        XCTAssertFalse(sut.isLoading)
    }
}
