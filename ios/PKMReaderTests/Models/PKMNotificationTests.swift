import XCTest
@testable import PKMReader

final class PKMNotificationTests: XCTestCase {
    // MARK: - PKMNotification

    func test_id_returnsNotificationId() {
        let notification = PKMNotification(
            notificationId: "notif-001",
            notificationType: .dailySummary,
            title: "Daily Summary",
            body: "Summary of 5 documents",
            deepLink: "/summaries/2026-02-23",
            timestamp: "2026-02-23T06:00:00Z",
            read: false
        )

        XCTAssertEqual(notification.id, "notif-001")
    }

    func test_codable_roundTrip() throws {
        let original = PKMNotification(
            notificationId: "notif-002",
            notificationType: .weeklyReport,
            title: "Weekly Report",
            body: "Report for week 08",
            deepLink: "/reports/2026-W08",
            timestamp: "2026-02-23T20:00:00Z",
            read: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PKMNotification.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func test_codable_withNilDeepLink() throws {
        let original = PKMNotification(
            notificationId: "notif-003",
            notificationType: .searchMonitor,
            title: "Search Update",
            body: "New results found",
            deepLink: nil,
            timestamp: "2026-02-23T12:00:00Z",
            read: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PKMNotification.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertNil(decoded.deepLink)
    }

    func test_decodable_fromJSON() throws {
        let json = Data("""
        {
            "notificationId": "notif-004",
            "notificationType": "daily_summary",
            "title": "Daily Summary: 2026-02-23",
            "body": "Summary of 3 documents",
            "deepLink": "/summaries/2026-02-23",
            "timestamp": "2026-02-23T06:00:00Z",
            "read": false
        }
        """.utf8)

        let notification = try JSONDecoder().decode(PKMNotification.self, from: json)

        XCTAssertEqual(notification.notificationId, "notif-004")
        XCTAssertEqual(notification.notificationType, .dailySummary)
        XCTAssertEqual(notification.title, "Daily Summary: 2026-02-23")
        XCTAssertEqual(notification.body, "Summary of 3 documents")
        XCTAssertEqual(notification.deepLink, "/summaries/2026-02-23")
        XCTAssertFalse(notification.read)
    }

    func test_hashable_equalNotificationsHaveSameHash() {
        let notif1 = PKMNotification(
            notificationId: "notif-001",
            notificationType: .dailySummary,
            title: "Test",
            body: "Body",
            deepLink: nil,
            timestamp: "2026-02-23T06:00:00Z",
            read: false
        )
        let notif2 = PKMNotification(
            notificationId: "notif-001",
            notificationType: .dailySummary,
            title: "Test",
            body: "Body",
            deepLink: nil,
            timestamp: "2026-02-23T06:00:00Z",
            read: false
        )

        XCTAssertEqual(notif1.hashValue, notif2.hashValue)
    }

    // MARK: - NotificationType

    func test_notificationType_rawValues() {
        XCTAssertEqual(NotificationType.searchMonitor.rawValue, "search_monitor")
        XCTAssertEqual(NotificationType.dailySummary.rawValue, "daily_summary")
        XCTAssertEqual(NotificationType.weeklyReport.rawValue, "weekly_report")
    }

    func test_notificationType_decodable() throws {
        let json = Data("\"search_monitor\"".utf8)
        let decoded = try JSONDecoder().decode(NotificationType.self, from: json)
        XCTAssertEqual(decoded, .searchMonitor)
    }

    // MARK: - NotificationListResponse

    func test_notificationListResponse_decodable() throws {
        let json = Data("""
        {
            "notifications": [
                {
                    "notificationId": "notif-001",
                    "notificationType": "daily_summary",
                    "title": "Test",
                    "body": "Body",
                    "timestamp": "2026-02-23T06:00:00Z",
                    "read": false
                }
            ],
            "count": 1
        }
        """.utf8)

        let response = try JSONDecoder().decode(NotificationListResponse.self, from: json)

        XCTAssertEqual(response.count, 1)
        XCTAssertEqual(response.notifications.count, 1)
        XCTAssertEqual(response.notifications[0].notificationId, "notif-001")
    }

    // MARK: - DeviceRegistrationRequest

    func test_deviceRegistrationRequest_encodable() throws {
        let request = DeviceRegistrationRequest(
            deviceToken: "abc123def456",
            deviceId: "device-001",
            platform: "ios",
            appVersion: "1.0.0"
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(DeviceRegistrationRequest.self, from: data)

        XCTAssertEqual(decoded.deviceToken, "abc123def456")
        XCTAssertEqual(decoded.deviceId, "device-001")
        XCTAssertEqual(decoded.platform, "ios")
        XCTAssertEqual(decoded.appVersion, "1.0.0")
    }

    // MARK: - DeviceRegistrationResponse

    func test_deviceRegistrationResponse_decodable() throws {
        let json = Data("""
        {
            "deviceId": "device-001",
            "registered": true
        }
        """.utf8)

        let response = try JSONDecoder().decode(DeviceRegistrationResponse.self, from: json)

        XCTAssertEqual(response.deviceId, "device-001")
        XCTAssertTrue(response.registered)
    }
}
