import XCTest
@testable import PKMReader

@MainActor
final class SettingsViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: SettingsViewModel!
    private var mockAuthService: MockAuthService!
    private var cacheClearCallCount: Int!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mockAuthService = MockAuthService()
        cacheClearCallCount = 0
        sut = SettingsViewModel(
            authService: mockAuthService,
            clearCacheHandler: { [weak self] in
                self?.cacheClearCallCount += 1
            },
            confirmationDuration: .zero
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockAuthService = nil
        cacheClearCallCount = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_notSigningOut() {
        XCTAssertFalse(sut.isSigningOut)
    }

    func test_initialState_notClearingCache() {
        XCTAssertFalse(sut.isClearingCache)
    }

    func test_initialState_cacheNotCleared() {
        XCTAssertFalse(sut.showCacheCleared)
    }

    // MARK: - Sign Out

    func test_signOut_callsAuthService() async {
        mockAuthService.isAuthenticatedValue = true
        await sut.signOut()

        XCTAssertEqual(mockAuthService.signOutCallCount, 1)
    }

    func test_signOut_completesWithoutError() async {
        mockAuthService.signOutResult = .success(())
        await sut.signOut()

        XCTAssertFalse(sut.isSigningOut)
    }

    func test_signOut_handlesError_gracefully() async {
        mockAuthService.signOutResult = .failure(AuthError.notAuthenticated)
        await sut.signOut()

        // Should still complete and reset signing out state
        XCTAssertFalse(sut.isSigningOut)
        XCTAssertEqual(mockAuthService.signOutCallCount, 1)
    }

    func test_signOut_error_setsErrorMessage() async {
        mockAuthService.signOutResult = .failure(AuthError.notAuthenticated)
        await sut.signOut()

        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - Clear Cache

    func test_clearCache_callsHandler() async {
        await sut.clearCache()

        XCTAssertEqual(cacheClearCallCount, 1)
    }

    func test_clearCache_completesSuccessfully() async {
        await sut.clearCache()

        XCTAssertFalse(sut.isClearingCache)
    }

    func test_clearCache_handlesError_gracefully() async {
        sut = SettingsViewModel(
            authService: mockAuthService,
            clearCacheHandler: { throw NSError(domain: "test", code: -1) },
            confirmationDuration: .zero
        )

        await sut.clearCache()

        // Should still complete and reset state
        XCTAssertFalse(sut.isClearingCache)
    }

    func test_clearCache_error_setsErrorMessage() async {
        sut = SettingsViewModel(
            authService: mockAuthService,
            clearCacheHandler: { throw NSError(domain: "test", code: -1) },
            confirmationDuration: .zero
        )

        await sut.clearCache()

        XCTAssertNotNil(sut.errorMessage)
    }

    func test_initialState_noErrorMessage() {
        XCTAssertNil(sut.errorMessage)
    }
}
