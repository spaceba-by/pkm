import XCTest

/// Page object for the Insights screen (calendar-based)
final class InsightsPage {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var insightsView: XCUIElement {
        app.otherElements["InsightsView"].firstMatch
    }

    var calendarView: XCUIElement {
        app.otherElements["CalendarView"].firstMatch
    }

    var monthTitle: XCUIElement {
        app.staticTexts["CalendarMonthTitle"].firstMatch
    }

    var previousMonthButton: XCUIElement {
        app.buttons["CalendarPreviousMonth"].firstMatch
    }

    var nextMonthButton: XCUIElement {
        app.buttons["CalendarNextMonth"].firstMatch
    }

    var emptyMonthLabel: XCUIElement {
        app.staticTexts["EmptyMonthLabel"].firstMatch
    }

    var dispatchLink: XCUIElement {
        app.buttons["DispatchNavigationLink"].firstMatch
    }

    // MARK: - Actions

    func tapPreviousMonth() {
        previousMonthButton.tap()
    }

    func tapNextMonth() {
        nextMonthButton.tap()
    }

    func tapDay(id: String) {
        app.buttons["CalendarDay_\(id)"].firstMatch.tap()
    }

    func tapWeekReportIndicator() {
        app.buttons["WeekReportIndicator"].firstMatch.tap()
    }

    // MARK: - Assertions

    func assertIsDisplayed(timeout: TimeInterval = 5) {
        XCTAssertTrue(insightsView.waitForExistence(timeout: timeout), "Insights screen not displayed")
    }

    func assertCalendarIsDisplayed(timeout: TimeInterval = 5) {
        XCTAssertTrue(calendarView.waitForExistence(timeout: timeout), "Calendar view not displayed")
    }
}
