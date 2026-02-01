import XCTest

@MainActor
extension XCUIApplication {
    /// Launch the app configured for UI testing
    func launchForTesting() {
        launchArguments = ["--uitesting"]
        launch()
    }

    /// Launch the app with mock API data
    func launchWithMockData() {
        launchArguments = ["--uitesting", "--mock-api"]
        launch()
    }

    /// Launch the app in a logged-out state
    func launchLoggedOut() {
        launchArguments = ["--uitesting", "--logged-out"]
        launch()
    }

    /// Launch the app with specific environment
    func launchWithEnvironment(_ environment: [String: String]) {
        launchArguments = ["--uitesting"]
        launchEnvironment = environment
        launch()
    }
}
