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

        // Navigate to Insights tab (may be behind "More" on iPhone with 6+ tabs)
        app.navigateToTab("Insights")
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        insightsPage = nil
    }

    // MARK: - Calendar Display Tests

    func test_insightsView_showsCalendar() throws {
        insightsPage.assertIsDisplayed()
        insightsPage.assertCalendarIsDisplayed()
    }

    func test_calendarShowsMonthTitle() throws {
        insightsPage.assertIsDisplayed()

        let monthTitle = insightsPage.monthTitle
        XCTAssertTrue(monthTitle.waitForExistence(timeout: 5), "Month title not displayed")
        XCTAssertFalse(monthTitle.label.isEmpty, "Month title should not be empty")
    }

    // MARK: - Month Navigation Tests

    func test_previousMonth_navigatesBack() throws {
        insightsPage.assertIsDisplayed()

        let monthTitle = insightsPage.monthTitle
        XCTAssertTrue(monthTitle.waitForExistence(timeout: 5))
        let originalTitle = monthTitle.label

        insightsPage.tapPreviousMonth()

        let newTitle = insightsPage.monthTitle.label
        XCTAssertNotEqual(originalTitle, newTitle, "Month title should change after navigation")
    }

    func test_nextMonth_navigatesForward() throws {
        insightsPage.assertIsDisplayed()

        let monthTitle = insightsPage.monthTitle
        XCTAssertTrue(monthTitle.waitForExistence(timeout: 5))
        let originalTitle = monthTitle.label

        insightsPage.tapNextMonth()

        let newTitle = insightsPage.monthTitle.label
        XCTAssertNotEqual(originalTitle, newTitle, "Month title should change after navigation")
    }

    // MARK: - Summary Tap Tests

    func test_tapDayWithSummary_showsDetail() throws {
        insightsPage.assertIsDisplayed()
        insightsPage.assertCalendarIsDisplayed()

        // Use today's date as the day ID since mock data includes today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayId = formatter.string(from: Date())

        let dayButton = app.buttons["CalendarDay_\(todayId)"]
        XCTAssertTrue(dayButton.waitForExistence(timeout: 5), "Today's calendar cell not found")
        dayButton.tap()

        // Verify navigation to summary detail via back button presence
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Summary detail view not displayed")
    }

    // MARK: - Report Tap Tests

    func test_tapReportIndicator_showsDetail() throws {
        insightsPage.assertIsDisplayed()
        insightsPage.assertCalendarIsDisplayed()

        let reportIndicator = app.buttons["WeekReportIndicator"].firstMatch
        guard reportIndicator.waitForExistence(timeout: 5) else {
            throw XCTSkip("No report indicator visible in current month")
        }
        reportIndicator.tap()

        // Verify navigation to report detail via back button presence
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Report detail view not displayed")
    }
}
