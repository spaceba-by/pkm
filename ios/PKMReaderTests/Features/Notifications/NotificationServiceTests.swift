@testable import PKMReader
import XCTest

@MainActor
final class NotificationServiceTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: NotificationService!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
        sut = NotificationService(apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_deviceTokenIsNil() {
        XCTAssertNil(sut.deviceToken)
    }

    func test_initialState_isRegisteredIsFalse() {
        XCTAssertFalse(sut.isRegistered)
    }

    // MARK: - didRegisterForRemoteNotifications

    func test_didRegister_convertsTokenToHexString() {
        let tokenData = Data([0xAB, 0xCD, 0xEF, 0x01, 0x23])
        sut.didRegisterForRemoteNotifications(deviceToken: tokenData)

        XCTAssertEqual(sut.deviceToken, "abcdef0123")
    }

    func test_didRegister_emptyToken_setsEmptyString() {
        let tokenData = Data()
        sut.didRegisterForRemoteNotifications(deviceToken: tokenData)

        XCTAssertEqual(sut.deviceToken, "")
    }

    func test_didRegister_callsBackendRegistration() async throws {
        let tokenData = Data([0xAA, 0xBB])
        sut.didRegisterForRemoteNotifications(deviceToken: tokenData)

        // Wait for the background Task to complete
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(mockAPIClient.registerDeviceCallCount, 1)
        XCTAssertTrue(sut.isRegistered)
    }

    func test_didRegister_backendFailure_setsNotRegistered() async throws {
        mockAPIClient.registerDeviceResult = .failure(APIError.invalidResponse)
        let tokenData = Data([0xAA, 0xBB])
        sut.didRegisterForRemoteNotifications(deviceToken: tokenData)

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(mockAPIClient.registerDeviceCallCount, 1)
        XCTAssertFalse(sut.isRegistered)
    }

    // MARK: - didFailToRegisterForRemoteNotifications

    func test_didFailToRegister_clearsDeviceToken() {
        sut.didFailToRegisterForRemoteNotifications(
            error: NSError(domain: "test", code: -1)
        )

        XCTAssertNil(sut.deviceToken)
        XCTAssertFalse(sut.isRegistered)
    }

    // MARK: - unregisterDevice

    func test_unregister_withoutRegistration_doesNothing() async {
        await sut.unregisterDevice()

        XCTAssertEqual(mockAPIClient.unregisterDeviceCallCount, 0)
    }

    func test_unregister_afterRegistration_callsBackend() async throws {
        let tokenData = Data([0xAA, 0xBB])
        sut.didRegisterForRemoteNotifications(deviceToken: tokenData)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(sut.isRegistered)

        await sut.unregisterDevice()

        XCTAssertEqual(mockAPIClient.unregisterDeviceCallCount, 1)
        XCTAssertFalse(sut.isRegistered)
        XCTAssertNil(sut.deviceToken)
    }

    func test_unregister_backendFailure_keepsState() async throws {
        let tokenData = Data([0xAA, 0xBB])
        sut.didRegisterForRemoteNotifications(deviceToken: tokenData)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(sut.isRegistered)

        mockAPIClient.unregisterDeviceResult = .failure(APIError.invalidResponse)
        await sut.unregisterDevice()

        // On failure, isRegistered stays true (error is silently caught)
        XCTAssertTrue(sut.isRegistered)
    }

    // MARK: - configure

    func test_configure_setsAPIClient() async throws {
        let service = NotificationService(apiClient: mockAPIClient)
        let newMock = MockAPIClient()
        service.configure(apiClient: newMock)

        let tokenData = Data([0xFF])
        service.didRegisterForRemoteNotifications(deviceToken: tokenData)
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(newMock.registerDeviceCallCount, 1)
        XCTAssertEqual(mockAPIClient.registerDeviceCallCount, 0)
    }
}
