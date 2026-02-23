@testable import PKMReader
import XCTest

@MainActor
final class DocumentCacheServiceTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: DocumentCacheService!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() async throws {
        try await super.setUp()
        sut = try DocumentCacheService(inMemory: true)
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Cache Documents

    func test_cacheDocuments_storesDocuments() {
        let documents = TestFixtures.sampleDocuments
        sut.cacheDocuments(documents)

        let cached = sut.getCachedDocuments(classification: nil)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, documents.count)
    }

    func test_cacheDocuments_updatesExisting() {
        let doc = TestFixtures.sampleDocument
        sut.cacheDocuments([doc])

        // Cache again with same ID
        let updated = Document(
            id: doc.id,
            title: "Updated Title",
            content: "Updated content",
            metadata: doc.metadata
        )
        sut.cacheDocuments([updated])

        let cached = sut.getCachedDocument(id: doc.id)
        XCTAssertEqual(cached?.title, "Updated Title")
    }

    // MARK: - Get Cached Documents

    func test_getCachedDocuments_returnsNil_whenEmpty() {
        let cached = sut.getCachedDocuments(classification: nil)
        XCTAssertNil(cached)
    }

    func test_getCachedDocuments_filtersByClassification() {
        sut.cacheDocuments(TestFixtures.sampleDocuments)

        let meetings = sut.getCachedDocuments(classification: .meeting)
        XCTAssertNotNil(meetings)
        XCTAssertEqual(meetings?.count, 1)
        XCTAssertEqual(meetings?.first?.metadata.classification, .meeting)
    }

    func test_getCachedDocuments_returnsNil_forNoMatchingClassification() {
        let doc = TestFixtures.sampleDocument // .reference
        sut.cacheDocuments([doc])

        let meetings = sut.getCachedDocuments(classification: .journal)
        XCTAssertNil(meetings)
    }

    // MARK: - Get Single Cached Document

    func test_getCachedDocument_returnsDocument() {
        sut.cacheDocuments([TestFixtures.sampleDocument])

        let cached = sut.getCachedDocument(id: TestFixtures.sampleDocument.id)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.id, TestFixtures.sampleDocument.id)
        XCTAssertEqual(cached?.title, TestFixtures.sampleDocument.title)
    }

    func test_getCachedDocument_returnsNil_whenNotCached() {
        let cached = sut.getCachedDocument(id: "nonexistent")
        XCTAssertNil(cached)
    }

    // MARK: - Clear Cache

    func test_clearCache_removesAllDocuments() {
        sut.cacheDocuments(TestFixtures.sampleDocuments)
        XCTAssertNotNil(sut.getCachedDocuments(classification: nil))

        sut.clearCache()
        XCTAssertNil(sut.getCachedDocuments(classification: nil))
    }

    // MARK: - Clear Stale Cache

    func test_clearStaleCache_doesNotRemoveFreshDocuments() {
        // Cache a document (it's fresh since we just cached it)
        sut.cacheDocuments([TestFixtures.sampleDocument])
        XCTAssertNotNil(sut.getCachedDocuments(classification: nil))

        // clearStaleCache should not remove freshly cached documents
        sut.clearStaleCache()
        let cached = sut.getCachedDocuments(classification: nil)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 1)
    }

    // MARK: - Document Conversion

    func test_cachedDocument_preservesTags() {
        let doc = TestFixtures.sampleDocument
        sut.cacheDocuments([doc])

        let cached = sut.getCachedDocument(id: doc.id)
        XCTAssertEqual(cached?.metadata.tags, doc.metadata.tags)
    }

    func test_cachedDocument_preservesContent() {
        let doc = TestFixtures.sampleDocument
        sut.cacheDocuments([doc])

        let cached = sut.getCachedDocument(id: doc.id)
        XCTAssertEqual(cached?.content, doc.content)
    }
}
