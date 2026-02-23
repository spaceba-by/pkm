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

        let cells = list.cells
        XCTAssertEqual(cells.count, 3, "Expected 3 document cells from mock data")
    }

    func test_documentList_showsDocumentTitles() throws {
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

        let filterNavBar = app.navigationBars["Filter"]
        XCTAssertTrue(filterNavBar.waitForExistence(timeout: 5), "Filter sheet not displayed")

        let allFilter = app.buttons["Filter_All"]
        XCTAssertTrue(allFilter.waitForExistence(timeout: 5), "All Documents filter not found")
    }

    func test_filterSheet_selectClassification_andApply() throws {
        let filterButton = app.buttons["FilterButton"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5))
        filterButton.tap()

        let meetingFilter = app.buttons["Filter_meeting"]
        XCTAssertTrue(meetingFilter.waitForExistence(timeout: 5), "Meeting filter not found")
        meetingFilter.tap()

        let applyButton = app.buttons["ApplyFilterButton"]
        XCTAssertTrue(applyButton.waitForExistence(timeout: 5), "Apply button not found")
        applyButton.tap()

        let filterNavBar = app.navigationBars["Filter"]
        XCTAssertFalse(filterNavBar.waitForExistence(timeout: 2), "Filter sheet should have dismissed")

        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Document list not displayed after filter")

        let meetingTitle = app.staticTexts["Team Meeting Notes"]
        XCTAssertTrue(meetingTitle.waitForExistence(timeout: 5), "Meeting document not shown after filter")

        let ideaTitle = app.staticTexts["App Redesign Ideas"]
        XCTAssertFalse(ideaTitle.exists, "Non-meeting document should be filtered out")
    }

    // MARK: - Navigation to Detail

    func test_tapDocument_navigatesToDetail() throws {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Document list not displayed")

        let firstCell = list.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "Document cell not found")
        firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Document detail not displayed")
    }

    // MARK: - Pull to Refresh

    func test_pullToRefresh_reloadsDocuments() throws {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Document list not displayed")

        list.swipeDown()

        XCTAssertTrue(list.waitForExistence(timeout: 5), "Document list not displayed after refresh")
    }

    // MARK: - Search Tests (migrated from SearchScreenTests)

    func test_search_showsResults() throws {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field not found")
        searchField.tap()
        searchField.typeText("meeting")

        let resultsList = app.collectionViews["SearchResultsList"]
        XCTAssertTrue(resultsList.waitForExistence(timeout: 5), "Search results not displayed")
    }

    func test_search_tapResult_navigatesToDetail() throws {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field not found")
        searchField.tap()
        searchField.typeText("meeting")

        let resultsList = app.collectionViews["SearchResultsList"]
        XCTAssertTrue(resultsList.waitForExistence(timeout: 5), "Search results not displayed")

        let firstCell = resultsList.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "Search result cell not found")
        firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Detail view not displayed")
    }

    func test_search_noResults_showsEmptyState() throws {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field not found")
        searchField.tap()
        searchField.typeText("zzzznonexistent")

        documentListPage.assertShowsSearchEmptyState(timeout: 5)
    }

    // MARK: - Search Monitors Access

    func test_searchMonitorsLink_exists() throws {
        let monitorsLink = app.buttons["SearchMonitorsLink"]
        XCTAssertTrue(monitorsLink.waitForExistence(timeout: 5), "Search monitors link not found")
    }

    func test_searchMonitorsLink_navigatesToMonitors() throws {
        let monitorsLink = app.buttons["SearchMonitorsLink"]
        XCTAssertTrue(monitorsLink.waitForExistence(timeout: 5), "Search monitors link not found")
        monitorsLink.tap()

        let navBar = app.navigationBars["Search Monitors"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Search Monitors view not displayed")
    }

    // MARK: - Tag Filter in Filter Sheet

    func test_filterSheet_showsTagsSection() throws {
        let filterButton = app.buttons["FilterButton"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5))
        filterButton.tap()

        let filterNavBar = app.navigationBars["Filter"]
        XCTAssertTrue(filterNavBar.waitForExistence(timeout: 5), "Filter sheet not displayed")

        // Tags section should be visible — use accessibilityIdentifier to avoid
        // ambiguity with classification names; scroll if needed
        let tagElement = app.buttons["Filter_Tag_swift"]
        if !tagElement.exists {
            app.swipeUp()
        }
        XCTAssertTrue(tagElement.waitForExistence(timeout: 5), "Tag not shown in filter sheet")
    }
}
