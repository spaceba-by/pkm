import XCTest

/// Page object for the Search Monitor screens
final class SearchMonitorPage {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - List Elements

    var listView: XCUIElement {
        app.otherElements["SearchMonitorListView"].firstMatch
    }

    var createButton: XCUIElement {
        app.buttons["CreateMonitorButton"].firstMatch
    }

    // MARK: - Detail Elements

    var detailView: XCUIElement {
        app.otherElements["SearchMonitorDetailView"].firstMatch
    }

    var actionsMenu: XCUIElement {
        app.buttons["MonitorActions"].firstMatch
    }

    // MARK: - Form Elements

    var formView: XCUIElement {
        app.otherElements["SearchMonitorFormView"].firstMatch
    }

    var nameField: XCUIElement {
        app.textFields["MonitorNameField"].firstMatch
    }

    var searchTermsField: XCUIElement {
        app.textFields["MonitorSearchTermsField"].firstMatch
    }

    var saveButton: XCUIElement {
        app.buttons["SaveMonitorButton"].firstMatch
    }

    // MARK: - Summary Elements

    var summaryView: XCUIElement {
        app.otherElements["SearchSummaryView"].firstMatch
    }

    // MARK: - Actions

    func tapMonitor(id: String) {
        let monitor = app.buttons["Monitor_\(id)"].firstMatch
        if monitor.waitForExistence(timeout: 5) {
            monitor.tap()
        }
    }

    func tapSummary(id: String) {
        let summary = app.buttons["Summary_\(id)"].firstMatch
        if summary.waitForExistence(timeout: 5) {
            summary.tap()
        }
    }

    // MARK: - Assertions

    func assertListDisplayed(timeout: TimeInterval = 5) {
        XCTAssertTrue(listView.waitForExistence(timeout: timeout), "Monitor list not displayed")
    }

    func assertDetailDisplayed(timeout: TimeInterval = 5) {
        XCTAssertTrue(detailView.waitForExistence(timeout: timeout), "Monitor detail not displayed")
    }

    func assertFormDisplayed(timeout: TimeInterval = 5) {
        XCTAssertTrue(formView.waitForExistence(timeout: timeout), "Monitor form not displayed")
    }

    func assertSummaryDisplayed(timeout: TimeInterval = 5) {
        XCTAssertTrue(summaryView.waitForExistence(timeout: timeout), "Summary view not displayed")
    }
}
