import XCTest

/// Graph screen tests using mock API infrastructure
final class GraphScreenTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var app: XCUIApplication!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchWithMockData()

        // Navigate to Graph tab (may be behind "More" on iPhone with 6+ tabs)
        app.navigateToTab("Graph")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Graph Display Tests

    func test_graphView_isDisplayed() throws {
        let graphView = app.otherElements["GraphView"]
        XCTAssertTrue(graphView.waitForExistence(timeout: 10), "Graph view not displayed")
    }

    func test_graphView_navigationTitle() throws {
        let navBar = app.navigationBars["Graph"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Graph navigation bar not found")
    }

    func test_graphView_hasLegendButton() throws {
        let legendButton = app.buttons["Graph legend"]
        XCTAssertTrue(legendButton.waitForExistence(timeout: 10), "Legend button not found")
    }

    func test_tapLegend_showsMenu() throws {
        let legendButton = app.buttons["Graph legend"]
        XCTAssertTrue(legendButton.waitForExistence(timeout: 10), "Legend button not found")
        legendButton.tap()

        // Menu items should appear
        let meetingLabel = app.buttons["Meeting"]
        XCTAssertTrue(meetingLabel.waitForExistence(timeout: 3), "Legend menu not shown")
    }
}
