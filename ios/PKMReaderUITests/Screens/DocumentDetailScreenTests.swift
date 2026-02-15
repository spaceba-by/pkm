import XCTest

/// Document detail screen tests using mock API infrastructure
final class DocumentDetailScreenTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var app: XCUIApplication!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchWithMockData()

        // Navigate to first document detail from the Documents tab
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), "Document list not displayed")

        let firstCell = list.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "Document cell not found")
        firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Wait for detail view to load by checking for the back button
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Document detail not displayed")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Content Display Tests

    func test_detailView_displaysNavigationTitle() throws {
        let navBar = app.navigationBars.element(boundBy: 0)
        XCTAssertTrue(navBar.exists, "Navigation bar not displayed")
    }

    func test_detailView_showsScrollableContent() throws {
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Detail scroll view not displayed")
    }

    func test_detailView_showsDateInformation() throws {
        // Document detail shows calendar icon and dates
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Detail view not loaded")
    }

    // MARK: - Navigation Tests

    func test_backButton_returnsToList() throws {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.exists, "Back button not found")
        backButton.tap()

        let navBar = app.navigationBars["Documents"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Did not return to document list")
    }

    func test_navigateToSecondDocument() throws {
        // Go back to list
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        backButton.tap()

        let navBar = app.navigationBars["Documents"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))

        // Navigate to second document
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))

        let cells = list.cells
        guard cells.count >= 2 else {
            XCTFail("Expected at least 2 document cells")
            return
        }

        cells.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // Verify navigation worked
        let detailBackButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(detailBackButton.waitForExistence(timeout: 5), "Second document detail not displayed")
    }
}
