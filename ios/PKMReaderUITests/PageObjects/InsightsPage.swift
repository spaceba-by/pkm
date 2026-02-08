import XCTest

/// Page object for the Insights screen
final class InsightsPage {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var insightsView: XCUIElement {
        app.otherElements["InsightsView"].firstMatch
    }

    var summariesSegment: XCUIElement {
        app.buttons["Summaries"].firstMatch
    }

    var reportsSegment: XCUIElement {
        app.buttons["Reports"].firstMatch
    }

    var summaryList: XCUIElement {
        app.collectionViews["SummaryList"].firstMatch
    }

    var reportList: XCUIElement {
        app.collectionViews["ReportList"].firstMatch
    }

    // MARK: - Actions

    func selectSummaries() {
        summariesSegment.tap()
    }

    func selectReports() {
        reportsSegment.tap()
    }

    func tapSummary(at index: Int) {
        summaryList.cells.element(boundBy: index).tap()
    }

    func tapReport(at index: Int) {
        reportList.cells.element(boundBy: index).tap()
    }

    // MARK: - Assertions

    func assertIsDisplayed(timeout: TimeInterval = 5) {
        XCTAssertTrue(insightsView.waitForExistence(timeout: timeout), "Insights screen not displayed")
    }
}
