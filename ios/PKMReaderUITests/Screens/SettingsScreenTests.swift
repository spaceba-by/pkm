import XCTest

/// Settings screen tests using mock API infrastructure
final class SettingsScreenTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var app: XCUIApplication!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchWithMockData()

        // Navigate to Settings tab (may be behind "More" on iPhone with 6+ tabs)
        app.navigateToTab("Settings")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Settings Tests

    func test_settingsView_displaysAllSections() {
        // Verify the Settings navigation title
        let navBar = app.navigationBars["Settings"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Settings navigation bar not displayed")

        // Verify key UI elements exist
        let clearCacheButton = app.buttons["ClearCacheButton"]
        XCTAssertTrue(clearCacheButton.waitForExistence(timeout: 5), "Clear Cache button not found")

        let signOutButton = app.buttons["SignOutButton"]
        XCTAssertTrue(signOutButton.exists, "Sign Out button not found")
    }

    func test_clearCache_buttonExists() {
        let clearCacheButton = app.buttons["ClearCacheButton"]
        XCTAssertTrue(clearCacheButton.waitForExistence(timeout: 5), "Clear Cache button not found")
        XCTAssertTrue(clearCacheButton.isEnabled, "Clear Cache button should be enabled")
    }

    func test_displayPreferences_toggles() {
        let compactToggle = app.switches["CompactListToggle"]
        XCTAssertTrue(compactToggle.waitForExistence(timeout: 5), "Compact List toggle not found")

        let previewsToggle = app.switches["ShowPreviewsToggle"]
        XCTAssertTrue(previewsToggle.exists, "Show Previews toggle not found")

        // Toggle compact mode
        compactToggle.tap()

        // Toggle previews
        previewsToggle.tap()
    }

    // MARK: - Tab Navigation

    func test_tabLayout_exists() {
        let tabBar = app.tabBars.element
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar not found")

        // 4 tabs: Documents, Insights, Settings, Graph
        let documentsTab = app.tabBars.buttons["Documents"]
        let insightsTab = app.tabBars.buttons["Insights"]
        let settingsTab = app.tabBars.buttons["Settings"]
        let graphTab = app.tabBars.buttons["Graph"]

        XCTAssertTrue(documentsTab.exists, "Documents tab not found")
        XCTAssertTrue(insightsTab.exists, "Insights tab not found")
        XCTAssertTrue(settingsTab.exists, "Settings tab not found")
        XCTAssertTrue(graphTab.exists, "Graph tab not found")
    }
}
