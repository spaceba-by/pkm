@testable import PKMReader
import XCTest

@MainActor
final class NotificationHandlerTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: NotificationHandler!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
        sut = NotificationHandler(apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_noPendingDeepLink() {
        XCTAssertNil(sut.pendingDeepLink)
    }

    func test_initialState_unreadCountIsZero() {
        XCTAssertEqual(sut.unreadCount, 0)
    }

    // MARK: - handleNotification

    func test_handleNotification_withDeepLink_setsPendingDeepLink() {
        sut.handleNotification(userInfo: ["deepLink": "/summaries/2026-02-23"])

        XCTAssertEqual(sut.pendingDeepLink, "/summaries/2026-02-23")
    }

    func test_handleNotification_withoutDeepLink_doesNotSetPendingDeepLink() {
        sut.handleNotification(userInfo: ["title": "Test"])

        XCTAssertNil(sut.pendingDeepLink)
    }

    func test_handleNotification_withNonStringDeepLink_doesNotSetPendingDeepLink() {
        sut.handleNotification(userInfo: ["deepLink": 123])

        XCTAssertNil(sut.pendingDeepLink)
    }

    // MARK: - setDeepLink

    func test_setDeepLink_setsPendingDeepLink() {
        sut.setDeepLink("/reports/2026-W08")

        XCTAssertEqual(sut.pendingDeepLink, "/reports/2026-W08")
    }

    // MARK: - clearDeepLink

    func test_clearDeepLink_clearsPendingDeepLink() {
        sut.setDeepLink("/test")
        sut.clearDeepLink()

        XCTAssertNil(sut.pendingDeepLink)
    }

    // MARK: - refreshUnreadCount

    func test_refreshUnreadCount_success_updatesCount() async {
        mockAPIClient.getUnviewedCountResult = .success(3)

        await sut.refreshUnreadCount()

        XCTAssertEqual(sut.unreadCount, 3)
        XCTAssertEqual(mockAPIClient.getUnviewedCountCallCount, 1)
    }

    func test_refreshUnreadCount_allRead_countsZero() async {
        mockAPIClient.getUnviewedCountResult = .success(0)

        await sut.refreshUnreadCount()

        XCTAssertEqual(sut.unreadCount, 0)
    }

    func test_refreshUnreadCount_failure_keepsCurrentCount() async {
        mockAPIClient.getUnviewedCountResult = .failure(APIError.invalidResponse)

        await sut.refreshUnreadCount()

        XCTAssertEqual(sut.unreadCount, 0)
    }

    func test_refreshUnreadCount_withoutAPIClient_doesNothing() async {
        let handler = NotificationHandler(apiClient: mockAPIClient)
        handler.configure(apiClient: mockAPIClient)
        mockAPIClient.getUnviewedCountResult = .success(0)
        await handler.refreshUnreadCount()
        XCTAssertEqual(handler.unreadCount, 0)
    }

    // MARK: - markAsRead

    func test_markAsRead_success_callsAPI() async {
        await sut.markAsRead(notificationId: "1")

        XCTAssertEqual(mockAPIClient.markNotificationReadCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastMarkNotificationReadId, "1")
    }

    func test_markAsRead_doesNotAffectUnreadCount() async {
        mockAPIClient.getUnviewedCountResult = .success(2)
        await sut.refreshUnreadCount()
        XCTAssertEqual(sut.unreadCount, 2)

        await sut.markAsRead(notificationId: "1")

        // markAsRead is for notifications, not insight viewed count
        XCTAssertEqual(sut.unreadCount, 2)
    }

    func test_markAsRead_doesNotGoNegative() {
        XCTAssertEqual(sut.unreadCount, 0)

        sut.decrementUnreadCount()

        XCTAssertEqual(sut.unreadCount, 0)
    }

    func test_markAsRead_failure_keepsCurrentCount() async {
        mockAPIClient.getUnviewedCountResult = .success(1)
        await sut.refreshUnreadCount()
        XCTAssertEqual(sut.unreadCount, 1)

        mockAPIClient.markNotificationReadResult = .failure(APIError.invalidResponse)
        await sut.markAsRead(notificationId: "1")

        XCTAssertEqual(sut.unreadCount, 1)
    }

    // MARK: - configure

    func test_configure_setsAPIClient() async {
        let handler = NotificationHandler(apiClient: mockAPIClient)
        let newMock = MockAPIClient()
        newMock.getUnviewedCountResult = .success(5)

        handler.configure(apiClient: newMock)
        await handler.refreshUnreadCount()

        XCTAssertEqual(newMock.getUnviewedCountCallCount, 1)
        XCTAssertEqual(handler.unreadCount, 5)
    }

    // MARK: - Helpers

    private func makeNotification(
        id: String,
        type: NotificationType = .dailySummary,
        read: Bool
    ) -> PKMNotification {
        PKMNotification(
            notificationId: id,
            notificationType: type,
            title: "Test",
            body: "Body",
            deepLink: nil,
            timestamp: "2026-02-23T06:00:00Z",
            read: read
        )
    }
}
