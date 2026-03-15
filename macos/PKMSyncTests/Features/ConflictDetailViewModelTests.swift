@testable import PKMSync
import XCTest

@MainActor
final class ConflictDetailViewModelTests: XCTestCase {
    private var mockDiffService: MockDiffService!
    private var mockConflictService: MockConflictService!
    private var conflict: ConflictFile!
    private var sut: ConflictDetailViewModel!

    override func setUp() {
        super.setUp()
        mockDiffService = MockDiffService()
        mockConflictService = MockConflictService()
        conflict = ConflictFile(
            originalPath: "/vault/note.md",
            conflictPath: "/vault/note.conflict1.md"
        )
        sut = ConflictDetailViewModel(
            conflict: conflict,
            vaultPath: "/vault",
            diffService: mockDiffService,
            conflictService: mockConflictService
        )
    }

    func testLoadDiffCallsService() async {
        mockDiffService.result = [
            DiffLine(id: 0, text: "context", type: .context),
            DiffLine(id: 1, text: "added", type: .added),
        ]

        await sut.loadDiff()

        XCTAssertEqual(mockDiffService.diffCallCount, 1)
        XCTAssertEqual(sut.diffLines.count, 2)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }

    func testLoadDiffHandlesError() async {
        mockDiffService.error = NSError(domain: "test", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "file not found",
        ])

        await sut.loadDiff()

        XCTAssertTrue(sut.diffLines.isEmpty)
        XCTAssertNotNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }

    func testResolveKeepOriginal() {
        sut.resolve(.keepOriginal)

        XCTAssertEqual(mockConflictService.resolveCallCount, 1)
        XCTAssertEqual(mockConflictService.lastResolution, .keepOriginal)
        XCTAssertTrue(sut.isResolved)
    }

    func testResolveKeepConflict() {
        sut.resolve(.keepConflict)

        XCTAssertEqual(mockConflictService.resolveCallCount, 1)
        XCTAssertEqual(mockConflictService.lastResolution, .keepConflict)
        XCTAssertTrue(sut.isResolved)
    }

    func testResolveCallsOnResolvedCallback() {
        var callbackCalled = false
        sut.onResolved = { callbackCalled = true }

        sut.resolve(.keepOriginal)

        XCTAssertTrue(callbackCalled)
    }
}
