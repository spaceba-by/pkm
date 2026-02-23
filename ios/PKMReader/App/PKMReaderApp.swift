import SwiftUI

@main
struct PKMReaderApp: App {
    init() {
        #if DEBUG
            if CommandLine.arguments.contains("--uitesting") {
                configureForUITesting()
            }
        #endif
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
