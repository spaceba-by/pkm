import XCTest

extension XCUIApplication {
    /// Terminate any running instance before launching to prevent simulator hangs on CI
    private func terminateIfRunning() {
        if state != .notRunning {
            terminate()
        }
    }

    /// Launch the app configured for UI testing
    func launchForTesting() {
        terminateIfRunning()
        launchArguments = ["--uitesting"]
        launch()
    }

    /// Launch the app with mock API data
    func launchWithMockData() {
        terminateIfRunning()
        launchArguments = ["--uitesting", "--mock-api"]
        launch()
    }

    /// Launch the app in a logged-out state
    func launchLoggedOut() {
        terminateIfRunning()
        launchArguments = ["--uitesting", "--logged-out"]
        launch()
    }

    /// Launch the app with specific environment
    func launchWithEnvironment(_ environment: [String: String]) {
        terminateIfRunning()
        launchArguments = ["--uitesting"]
        launchEnvironment = environment
        launch()
    }

    /// Navigate to a tab, handling the "More" overflow tab if needed.
    /// On iPhone with 6+ tabs, iOS shows 4 visible tabs + "More".
    func navigateToTab(_ tabName: String, timeout: TimeInterval = 5) {
        let directTab = tabBars.buttons[tabName]
        if directTab.waitForExistence(timeout: timeout) {
            directTab.tap()
            return
        }
        // Tab might be behind "More"
        let moreTab = tabBars.buttons["More"]
        if moreTab.waitForExistence(timeout: timeout) {
            moreTab.tap()
            let moreRow = tables.cells.staticTexts[tabName]
            if moreRow.waitForExistence(timeout: timeout) {
                moreRow.tap()
            }
        }
    }
}
