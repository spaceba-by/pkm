import XCTest
@testable import PKMReader

@MainActor
final class SearchViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: SearchViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
        sut = SearchViewModel(apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_isIdle() {
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.searchText, "")
    }

    // MARK: - Query Validation

    func test_shortQuery_remainsIdle() async {
        sut.searchText = "a"
        // Wait for debounce
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(mockAPIClient.searchCallCount, 0)
    }

    func test_emptyQuery_remainsIdle() async {
        sut.searchText = ""
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(mockAPIClient.searchCallCount, 0)
    }

    func test_whitespaceOnlyQuery_remainsIdle() async {
        sut.searchText = "  "
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(mockAPIClient.searchCallCount, 0)
    }

    // MARK: - Successful Search

    func test_validQuery_returnsResults() async {
        mockAPIClient.searchResult = .success(TestFixtures.sampleDocuments)
        sut.searchText = "sample"
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(sut.state, .loaded(TestFixtures.sampleDocuments))
        XCTAssertEqual(mockAPIClient.searchCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastSearchQuery, "sample")
    }

    func test_validQuery_emptyResults_showsEmpty() async {
        mockAPIClient.searchResult = .success([])
        sut.searchText = "nonexistent"
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(sut.state, .empty)
        XCTAssertEqual(mockAPIClient.searchCallCount, 1)
    }

    // MARK: - Error Handling

    func test_searchError_showsError() async {
        mockAPIClient.searchResult = .failure(APIError.networkError)
        sut.searchText = "test query"
        try? await Task.sleep(for: .milliseconds(400))
        if case .error = sut.state {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
        XCTAssertEqual(mockAPIClient.searchCallCount, 1)
    }

    // MARK: - Debounce

    func test_rapidTyping_onlySendsOneRequest() async {
        mockAPIClient.searchResult = .success(TestFixtures.sampleDocuments)
        sut.searchText = "te"
        sut.searchText = "tes"
        sut.searchText = "test"
        try? await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(mockAPIClient.searchCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastSearchQuery, "test")
    }

    // MARK: - Direct Search

    func test_directSearch_skipsDebounce() async {
        mockAPIClient.searchResult = .success(TestFixtures.sampleDocuments)
        sut.searchText = "direct"
        await sut.search()
        XCTAssertEqual(sut.state, .loaded(TestFixtures.sampleDocuments))
    }

    func test_directSearch_shortQuery_goesIdle() async {
        sut.searchText = "a"
        await sut.search()
        XCTAssertEqual(sut.state, .idle)
    }
}
