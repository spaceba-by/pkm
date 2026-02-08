import XCTest
@testable import PKMReader

@MainActor
final class ReportsViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: ReportsViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
        sut = ReportsViewModel(apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_isLoading() {
        XCTAssertEqual(sut.state, .loading)
    }

    // MARK: - Load Reports

    func test_loadReports_success_showsLoaded() async {
        mockAPIClient.listReportsResult = .success(TestFixtures.sampleReports)
        await sut.loadReports()

        if case .loaded(let reports) = sut.state {
            XCTAssertEqual(reports.count, 3)
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
    }

    func test_loadReports_emptyResult_showsEmpty() async {
        mockAPIClient.listReportsResult = .success([])
        await sut.loadReports()
        XCTAssertEqual(sut.state, .empty)
    }

    func test_loadReports_error_showsError() async {
        mockAPIClient.listReportsResult = .failure(APIError.networkError)
        await sut.loadReports()

        if case .error = sut.state {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
    }

    // MARK: - Refresh

    func test_refresh_reloadsData() async {
        mockAPIClient.listReportsResult = .success(TestFixtures.sampleReports)
        await sut.refresh()

        if case .loaded(let reports) = sut.state {
            XCTAssertEqual(reports.count, 3)
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
    }
}
