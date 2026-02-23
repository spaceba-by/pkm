import SwiftUI
import UserNotifications

/// App delegate to handle push notification registration callbacks
final class AppDelegate: NSObject, UIApplicationDelegate, Sendable {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            NotificationService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            NotificationService.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }
}

@main
struct PKMReaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        #if DEBUG
            if CommandLine.arguments.contains("--uitesting") {
                configureForUITesting()
            }
        #endif

        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    #if DEBUG
        private func configureForUITesting() {
            // Clear any cached state for clean UI tests
            UserDefaults.standard.removePersistentDomain(
                forName: Bundle.main.bundleIdentifier ?? ""
            )
        }
    #endif
}
