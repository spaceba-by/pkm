import XCTest

/// Insights screen tests using mock API infrastructure
final class InsightsScreenTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var app: XCUIApplication!
    private var insightsPage: InsightsPage!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchWithMockData()
        insightsPage = InsightsPage(app: app)

        // Navigate to Insights tab
        let insightsTab = app.tabBars.buttons["Insights"]
        XCTAssertTrue(insightsTab.waitForExistence(timeout: 5), "Insights tab not found")
        insightsTab.tap()
    }

    override func tearDownWithError() throws {
        app = nil
        insightsPage = nil
    }

    // MARK: - Insights Flow Tests

    func test_insightsView_showsSummaries() throws {
        insightsPage.assertIsDisplayed()

        // Summaries should be the default segment
        let summaryList = insightsPage.summaryList
        XCTAssertTrue(summaryList.waitForExistence(timeout: 5), "Summary list not displayed")
    }

    func test_switchToReports_showsReports() throws {
        insightsPage.assertIsDisplayed()

        // Switch to Reports segment
        insightsPage.selectReports()

        let reportList = insightsPage.reportList
        XCTAssertTrue(reportList.waitForExistence(timeout: 5), "Report list not displayed")
    }

    func test_tapSummary_showsDetail() throws {
        insightsPage.assertIsDisplayed()

        let summaryList = insightsPage.summaryList
        XCTAssertTrue(summaryList.waitForExistence(timeout: 5), "Summary list not displayed")

        // Coordinate tap on first cell to reliably trigger NavigationLink
        let firstCell = summaryList.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "Summary cell not found")
        firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Verify navigation to summary detail
        let detailView = app.otherElements["SummaryDetailView"]
        XCTAssertTrue(detailView.waitForExistence(timeout: 5), "Summary detail view not displayed")
    }

    func test_tapReport_showsDetail() throws {
        insightsPage.assertIsDisplayed()

        // Switch to Reports
        insightsPage.selectReports()

        let reportList = insightsPage.reportList
        XCTAssertTrue(reportList.waitForExistence(timeout: 5), "Report list not displayed")

        // Coordinate tap on first cell to reliably trigger NavigationLink
        let firstCell = reportList.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "Report cell not found")
        firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Verify navigation to report detail
        let detailView = app.otherElements["ReportDetailView"]
        XCTAssertTrue(detailView.waitForExistence(timeout: 5), "Report detail view not displayed")
    }
}
