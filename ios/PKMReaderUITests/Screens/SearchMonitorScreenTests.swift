import XCTest

/// Search Monitor screen tests using mock API infrastructure
final class SearchMonitorScreenTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var app: XCUIApplication!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchWithMockData()

        // Navigate to Search Monitors via Documents tab toolbar button
        let monitorsLink = app.buttons["SearchMonitorsLink"].firstMatch
        XCTAssertTrue(monitorsLink.waitForExistence(timeout: 5), "Search Monitors link not found")
        monitorsLink.tap()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - List View Tests

    func test_monitorList_displaysMonitors() throws {
        let monitor1 = app.staticTexts["Swift Concurrency Updates"]
        XCTAssertTrue(monitor1.waitForExistence(timeout: 10), "First monitor not shown")

        let monitor2 = app.staticTexts["AI Research"]
        XCTAssertTrue(monitor2.waitForExistence(timeout: 5), "Second monitor not shown")
    }

    func test_monitorList_showsStatusBadges() throws {
        let activeBadge = app.staticTexts["Active"]
        XCTAssertTrue(activeBadge.waitForExistence(timeout: 10), "Active badge not shown")

        let pausedBadge = app.staticTexts["Paused"]
        XCTAssertTrue(pausedBadge.waitForExistence(timeout: 5), "Paused badge not shown")
    }

    func test_monitorList_showsCreateButton() throws {
        let createButton = app.buttons["CreateMonitorButton"].firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 10), "Create button not shown")
    }

    func test_monitorList_showsNavigationTitle() throws {
        let navBar = app.navigationBars["Search Monitors"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Navigation title not shown")
    }

    func test_monitorList_showsSearchTerms() throws {
        let monitor1 = app.staticTexts["Swift Concurrency Updates"]
        XCTAssertTrue(monitor1.waitForExistence(timeout: 10))

        let termsText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'swift concurrency'"))
        XCTAssertGreaterThan(termsText.count, 0, "Search terms not shown")
    }

    func test_monitorList_showsInterval() throws {
        let monitor1 = app.staticTexts["Swift Concurrency Updates"]
        XCTAssertTrue(monitor1.waitForExistence(timeout: 10))

        let intervalText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Every 12h'"))
        XCTAssertGreaterThan(intervalText.count, 0, "Interval not shown")
    }

    func test_form_cancelDismisses() throws {
        let createButton = app.buttons["CreateMonitorButton"].firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 10))
        createButton.tap()

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Cancel button not found")
        cancelButton.tap()

        let monitor1 = app.staticTexts["Swift Concurrency Updates"]
        XCTAssertTrue(monitor1.waitForExistence(timeout: 5), "Monitor list not shown after cancel")
    }

    func test_form_showsNameField() throws {
        let createButton = app.buttons["CreateMonitorButton"].firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 10))
        createButton.tap()

        let nameField = app.textFields["MonitorNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Name field not shown")
    }

    func test_form_showsSearchTermsField() throws {
        let createButton = app.buttons["CreateMonitorButton"].firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 10))
        createButton.tap()

        let searchTermsField = app.textFields["MonitorSearchTermsField"]
        XCTAssertTrue(searchTermsField.waitForExistence(timeout: 5), "Search terms field not shown")
    }

    func test_form_showsNewMonitorTitle() throws {
        let createButton = app.buttons["CreateMonitorButton"].firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 10))
        createButton.tap()

        let navBar = app.navigationBars["New Monitor"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "New Monitor title not shown")
    }
}
