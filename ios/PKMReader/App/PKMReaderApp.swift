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
            ContentView()
        }
    }

    #if DEBUG
    private func configureForUITesting() {
        // Configure app for UI testing with mock data
        // This will be expanded when we implement the full auth flow
    }
    #endif
}
