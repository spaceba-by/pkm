@testable import PKMReader
import XCTest

@MainActor
final class SummariesViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: SummariesViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
        sut = SummariesViewModel(apiClient: mockAPIClient)
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

    // MARK: - Load Summaries

    func test_loadSummaries_success_showsLoaded() async {
        mockAPIClient.listSummariesResult = .success(TestFixtures.sampleSummaries)
        await sut.loadSummaries()

        if case let .loaded(summaries) = sut.state {
            XCTAssertEqual(summaries.count, 3)
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
    }

    func test_loadSummaries_emptyResult_showsEmpty() async {
        mockAPIClient.listSummariesResult = .success([])
        await sut.loadSummaries()
        XCTAssertEqual(sut.state, .empty)
    }

    func test_loadSummaries_error_showsError() async {
        mockAPIClient.listSummariesResult = .failure(APIError.networkError)
        await sut.loadSummaries()

        if case .error = sut.state {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
    }

    // MARK: - State Equality

    func test_state_loaded_equality() {
        let summaries = TestFixtures.sampleSummaries
        XCTAssertEqual(
            SummariesViewModel.State.loaded(summaries),
            SummariesViewModel.State.loaded(summaries)
        )
    }

    func test_state_error_equality() {
        let state1 = SummariesViewModel.State.error(APIError.networkError)
        let state2 = SummariesViewModel.State.error(APIError.networkError)
        XCTAssertEqual(state1, state2)
    }

    func test_state_different_notEqual() {
        XCTAssertNotEqual(SummariesViewModel.State.loading, SummariesViewModel.State.empty)
    }

    // MARK: - Refresh

    func test_refresh_reloadsData() async {
        mockAPIClient.listSummariesResult = .success(TestFixtures.sampleSummaries)
        await sut.refresh()

        if case let .loaded(summaries) = sut.state {
            XCTAssertEqual(summaries.count, 3)
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
    }
}
