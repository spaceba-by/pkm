import XCTest

/// Document list screen tests using mock API infrastructure
final class DocumentListScreenTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var app: XCUIApplication!
    private var documentListPage: DocumentListPage!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchWithMockData()
        documentListPage = DocumentListPage(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        documentListPage = nil
    }

    // MARK: - Navigation Tests

    func test_navigationTitle_displays() throws {
        let navBar = app.navigationBars["Documents"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Documents navigation bar not displayed")
    }

    // MARK: - Document List Tests

    func test_documentList_displaysDocuments() throws {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Document list not displayed")

        // Mock data has 3 documents
        let firstCell = list.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "No document cells found")
    }

    func test_documentList_showsDocumentTitles() throws {
        // Verify fixture document titles appear
        let meetingTitle = app.staticTexts["Team Meeting Notes"]
        XCTAssertTrue(meetingTitle.waitForExistence(timeout: 5), "Meeting document title not found")
    }

    // MARK: - Filter Tests

    func test_filterButton_exists() throws {
        let filterButton = app.buttons["FilterButton"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5), "Filter button not found")
    }

    func test_filterButton_opensFilterSheet() throws {
        let filterButton = app.buttons["FilterButton"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5), "Filter button not found")
        filterButton.tap()

        // Verify filter sheet appeared
        let filterNavBar = app.navigationBars["Filter"]
        XCTAssertTrue(filterNavBar.waitForExistence(timeout: 5), "Filter sheet not displayed")

        // Verify "All Documents" option exists
        let allFilter = app.buttons["Filter_All"]
        XCTAssertTrue(allFilter.waitForExistence(timeout: 5), "All Documents filter not found")
    }

    func test_filterSheet_selectClassification_andApply() throws {
        let filterButton = app.buttons["FilterButton"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5))
        filterButton.tap()

        // Select meeting filter
        let meetingFilter = app.buttons["Filter_meeting"]
        XCTAssertTrue(meetingFilter.waitForExistence(timeout: 5), "Meeting filter not found")
        meetingFilter.tap()

        // Tap Apply
        let applyButton = app.buttons["ApplyFilterButton"]
        XCTAssertTrue(applyButton.waitForExistence(timeout: 5), "Apply button not found")
        applyButton.tap()

        // Filter sheet should dismiss
        let filterNavBar = app.navigationBars["Filter"]
        XCTAssertFalse(filterNavBar.waitForExistence(timeout: 2), "Filter sheet should have dismissed")
    }

    // MARK: - Navigation to Detail

    func test_tapDocument_navigatesToDetail() throws {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Document list not displayed")

        let firstCell = list.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "Document cell not found")
        firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Verify navigation to detail view via back button presence
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Document detail not displayed")
    }

    // MARK: - Pull to Refresh

    func test_pullToRefresh_reloadsDocuments() throws {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Document list not displayed")

        // Swipe down to trigger refresh
        list.swipeDown()

        // List should still be displayed after refresh
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Document list not displayed after refresh")
    }
}
