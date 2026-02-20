import XCTest
@testable import PKMReader

@MainActor
final class TagsViewModelTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: TagsViewModel!
    private var mockAPIClient: MockAPIClient!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        mockAPIClient = MockAPIClient()
        sut = TagsViewModel(apiClient: mockAPIClient)
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

    // MARK: - Load Tags

    func test_loadTags_success_showsLoadedSortedByCount() async {
        mockAPIClient.listTagsResult = .success(TestFixtures.sampleTags)
        await sut.loadTags()

        if case .loaded(let tags) = sut.state {
            XCTAssertEqual(tags.count, 4)
            // Verify sort by document count descending (alphabetical tiebreaker)
            XCTAssertEqual(tags[0].name, "meeting")   // 10
            XCTAssertEqual(tags[1].name, "project")    // 7
            XCTAssertEqual(tags[2].name, "test")       // 5
            XCTAssertEqual(tags[3].name, "idea")       // 3
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
        XCTAssertEqual(mockAPIClient.listTagsCallCount, 1)
    }

    func test_loadTags_emptyResult_showsEmpty() async {
        mockAPIClient.listTagsResult = .success([])
        await sut.loadTags()
        XCTAssertEqual(sut.state, .empty)
    }

    func test_loadTags_error_showsError() async {
        mockAPIClient.listTagsResult = .failure(APIError.networkError)
        await sut.loadTags()

        if case .error = sut.state {
            // Expected
        } else {
            XCTFail("Expected error state, got \(sut.state)")
        }
    }

    // MARK: - Refresh

    func test_refresh_reloadsData() async {
        mockAPIClient.listTagsResult = .success(TestFixtures.sampleTags)
        await sut.refresh()

        if case .loaded(let tags) = sut.state {
            XCTAssertEqual(tags.count, 4)
        } else {
            XCTFail("Expected loaded state, got \(sut.state)")
        }
        XCTAssertEqual(mockAPIClient.listTagsCallCount, 1)
    }
}
