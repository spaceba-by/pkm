@testable import PKMSync
import XCTest

final class DiffServiceTests: XCTestCase {
    private var sut: DiffService!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        sut = DiffService()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiffServiceTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testDiffWithIdenticalFiles() async throws {
        let content = "line 1\nline 2\nline 3\n"
        let file1 = tempDir.appendingPathComponent("original.md")
        let file2 = tempDir.appendingPathComponent("conflict.md")
        try content.write(to: file1, atomically: true, encoding: .utf8)
        try content.write(to: file2, atomically: true, encoding: .utf8)

        let lines = try await sut.diff(originalPath: file1.path, conflictPath: file2.path)

        XCTAssertTrue(lines.isEmpty)
    }

    func testDiffWithDifferentFiles() async throws {
        let file1 = tempDir.appendingPathComponent("original.md")
        let file2 = tempDir.appendingPathComponent("conflict.md")
        try "line 1\nline 2\nline 3\n".write(to: file1, atomically: true, encoding: .utf8)
        try "line 1\nchanged line\nline 3\n".write(to: file2, atomically: true, encoding: .utf8)

        let lines = try await sut.diff(originalPath: file1.path, conflictPath: file2.path)

        let addedLines = lines.filter { $0.type == .added }
        let removedLines = lines.filter { $0.type == .removed }

        XCTAssertFalse(addedLines.isEmpty)
        XCTAssertFalse(removedLines.isEmpty)
        XCTAssertTrue(addedLines.contains { $0.text == "changed line" })
        XCTAssertTrue(removedLines.contains { $0.text == "line 2" })
    }

    func testDiffWithMissingOriginal() async throws {
        let file2 = tempDir.appendingPathComponent("conflict.md")
        try "new content\n".write(to: file2, atomically: true, encoding: .utf8)

        let lines = try await sut.diff(
            originalPath: tempDir.appendingPathComponent("missing.md").path,
            conflictPath: file2.path
        )

        XCTAssertTrue(lines.allSatisfy { $0.type == .added })
    }

    func testDiffWithMissingConflict() async throws {
        let file1 = tempDir.appendingPathComponent("original.md")
        try "original content\n".write(to: file1, atomically: true, encoding: .utf8)

        let lines = try await sut.diff(
            originalPath: file1.path,
            conflictPath: tempDir.appendingPathComponent("missing.md").path
        )

        XCTAssertTrue(lines.allSatisfy { $0.type == .removed })
    }

    func testDiffWithBothMissing() async throws {
        let lines = try await sut.diff(
            originalPath: tempDir.appendingPathComponent("a.md").path,
            conflictPath: tempDir.appendingPathComponent("b.md").path
        )

        XCTAssertTrue(lines.isEmpty)
    }

    func testParseDiffOutput() {
        let output = """
        --- a/file.md
        +++ b/file.md
        @@ -1,3 +1,3 @@
         context line
        -removed line
        +added line
         more context
        """

        let lines = sut.parseDiffOutput(output)

        let headers = lines.filter { $0.type == .header }
        let added = lines.filter { $0.type == .added }
        let removed = lines.filter { $0.type == .removed }
        let context = lines.filter { $0.type == .context }

        XCTAssertEqual(headers.count, 1)
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.text, "added line")
        XCTAssertEqual(removed.count, 1)
        XCTAssertEqual(removed.first?.text, "removed line")
        XCTAssertFalse(context.isEmpty)
    }
}
