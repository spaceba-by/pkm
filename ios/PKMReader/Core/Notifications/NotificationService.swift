import Foundation
import os.log
import UIKit
import UserNotifications

/// Protocol for notification service to enable testing
protocol NotificationServiceProtocol: Sendable {
    /// Request notification permission and register for remote notifications
    func requestAuthorization() async throws -> Bool

    /// Whether the user has granted notification permission
    var isAuthorized: Bool { get async }
}

/// Manages APNs registration and device token lifecycle
@MainActor
final class NotificationService: NSObject, NotificationServiceProtocol, ObservableObject {
    static let shared = NotificationService()

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PKMReader",
        category: "Notifications"
    )

    @Published private(set) var deviceToken: String?
    @Published private(set) var isRegistered = false
    @Published private(set) var registrationError: String?

    private var apiClient: (any APIClientProtocol)?
    private var registeredDeviceId: String?

    // swiftlint:disable:next modifier_order
    private override init() {
        super.init()
    }

    /// Internal init for testing
    init(apiClient: any APIClientProtocol) {
        super.init()
        self.apiClient = apiClient
    }

    /// Set the API client for device token registration
    func configure(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        Self.logger.info("Notification authorization granted: \(granted)")
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
            Self.logger.info("Called registerForRemoteNotifications")
        }
        return granted
    }

    var isAuthorized: Bool {
        get async {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    }

    /// Called when APNs returns a device token
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Self.logger.info("Received APNs device token (\(tokenString.prefix(8))...)")
        self.deviceToken = tokenString
        registrationError = nil
        Task {
            await registerDeviceTokenWithBackend(tokenString)
        }
    }

    /// Called when APNs registration fails
    func didFailToRegisterForRemoteNotifications(error: Error) {
        Self.logger.error("APNs registration failed: \(error.localizedDescription)")
        registrationError = "APNs registration failed: \(error.localizedDescription)"
        deviceToken = nil
        isRegistered = false
    }

    private func registerDeviceTokenWithBackend(_ token: String) async {
        guard let apiClient else { return }

        let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        let request = DeviceRegistrationRequest(
            deviceToken: token,
            deviceId: deviceId,
            platform: "ios",
            appVersion: appVersion
        )

        do {
            _ = try await apiClient.registerDevice(request: request)
            registeredDeviceId = deviceId
            isRegistered = true
            registrationError = nil
            Self.logger.info("Device token registered with backend successfully")
        } catch {
            Self.logger.error("Backend device registration failed: \(error.localizedDescription)")
            registrationError = "Backend registration failed: \(error.localizedDescription)"
            isRegistered = false
        }
    }

    /// Unregister the current device from push notifications
    func unregisterDevice() async {
        guard let apiClient, let deviceId = registeredDeviceId else { return }

        do {
            try await apiClient.unregisterDevice(deviceId: deviceId)
            isRegistered = false
            deviceToken = nil
            registeredDeviceId = nil
        } catch {
            print("Failed to unregister device: \(error.localizedDescription)")
        }
    }
}
