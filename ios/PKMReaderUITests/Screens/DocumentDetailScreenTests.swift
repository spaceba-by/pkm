import XCTest

/// Document detail screen tests using mock API infrastructure
final class DocumentDetailScreenTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var app: XCUIApplication!
    // swiftlint:enable implicitly_unwrapped_optional

    /// Navigate to the first document's detail view
    private func navigateToFirstDocument() {
        let meetingTitle = app.staticTexts["Team Meeting Notes"]
        XCTAssertTrue(meetingTitle.waitForExistence(timeout: 5), "Meeting title not found")
        meetingTitle.tap()
    }

    /// Wait for the detail view to finish loading by checking for the scroll view
    private func waitForDetailView() {
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Detail scroll view not loaded")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchWithMockData()

        // Wait for the document list to load
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Document list not displayed")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Content Display Tests

    func test_detailView_displaysNavigationTitle() {
        navigateToFirstDocument()
        waitForDetailView()

        // The inline nav title for this document should be "Team Meeting Notes"
        let navBar = app.navigationBars["Team Meeting Notes"]
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "Expected navigation bar titled 'Team Meeting Notes'"
        )
    }

    func test_detailView_showsScrollableContent() {
        navigateToFirstDocument()

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Detail scroll view not displayed")
    }

    func test_detailView_showsDateInformation() {
        navigateToFirstDocument()
        waitForDetailView()

        // Verify "Modified" relative date label is displayed in the detail view
        let modifiedText = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Modified'")
        )
        XCTAssertGreaterThan(modifiedText.count, 0, "Modified date label not found")
    }

    // MARK: - Navigation Tests

    func test_backButton_returnsToList() {
        navigateToFirstDocument()
        waitForDetailView()

        let backButton = app.navigationBars.buttons["Documents"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Back button not found")
        backButton.tap()

        let navBar = app.navigationBars["Documents"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Did not return to document list")
    }

    func test_navigateToSecondDocument() {
        // Navigate to second document by title
        let secondTitle = app.staticTexts["App Redesign Ideas"]
        XCTAssertTrue(secondTitle.waitForExistence(timeout: 5), "Second document title not found")
        secondTitle.tap()
        waitForDetailView()

        // Verify the second document's title in the nav bar
        let navBar = app.navigationBars["App Redesign Ideas"]
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "Expected navigation bar titled 'App Redesign Ideas'"
        )
    }
}
