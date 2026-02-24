import Foundation

/// Type of push notification
enum NotificationType: String, Codable, Sendable {
    case searchMonitor = "search_monitor"
    case dailySummary = "daily_summary"
    case weeklyReport = "weekly_report"
}

/// A notification record from the backend
struct PKMNotification: Identifiable, Codable, Hashable, Sendable {
    let notificationId: String
    let notificationType: NotificationType
    let title: String
    let body: String
    let deepLink: String?
    let timestamp: String
    let read: Bool

    var id: String {
        notificationId
    }
}

/// Response from GET /notifications
struct NotificationListResponse: Codable, Sendable {
    let notifications: [PKMNotification]
    let count: Int
}

/// Request body for POST /devices
struct DeviceRegistrationRequest: Codable, Sendable {
    let deviceToken: String
    let deviceId: String
    let platform: String
    let appVersion: String
}

/// Response from POST /devices
struct DeviceRegistrationResponse: Codable, Sendable {
    let deviceId: String
    let registered: Bool
}
