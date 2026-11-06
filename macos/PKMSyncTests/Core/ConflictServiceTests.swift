@testable import PKMSync
import XCTest

final class ConflictServiceTests: XCTestCase {
    private var tempDir: URL!
    private var sut: ConflictService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConflictServiceTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        sut = ConflictService()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testScanFindsConflictFiles() async throws {
        let original = tempDir.appendingPathComponent("note.md")
        let conflict = tempDir.appendingPathComponent("note.conflict1.md")
        try "original content".write(to: original, atomically: true, encoding: .utf8)
        try "conflict content".write(to: conflict, atomically: true, encoding: .utf8)

        let conflicts = try await sut.scanForConflicts(in: tempDir.path)

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertTrue(conflicts[0].conflictPath.contains("conflict1"))
    }

    func testScanReturnsEmptyForNoConflicts() async throws {
        try "content".write(
            to: tempDir.appendingPathComponent("note.md"),
            atomically: true,
            encoding: .utf8
        )

        let conflicts = try await sut.scanForConflicts(in: tempDir.path)

        XCTAssertTrue(conflicts.isEmpty)
    }

    func testScanReturnsEmptyForNonexistentPath() async throws {
        let conflicts = try await sut.scanForConflicts(in: "/nonexistent/path")

        XCTAssertTrue(conflicts.isEmpty)
    }

    func testScanIgnoresConflictFilesUnderAgentDirectory() async throws {
        let entities = tempDir.appendingPathComponent("_agent/entities/concepts")
        try FileManager.default.createDirectory(at: entities, withIntermediateDirectories: true)
        try "stale".write(
            to: entities.appendingPathComponent("trigger.md.conflict1"),
            atomically: true,
            encoding: .utf8
        )
        let note = tempDir.appendingPathComponent("note.md.conflict1")
        try "conflict".write(to: note, atomically: true, encoding: .utf8)

        let conflicts = try await sut.scanForConflicts(in: tempDir.path)

        XCTAssertEqual(conflicts.map { ($0.conflictPath as NSString).lastPathComponent }, ["note.md.conflict1"])
    }

    func testScanFindsConflictFilesInNestedDirectoryNamedAgent() async throws {
        let nested = tempDir.appendingPathComponent("projects/_agent")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "conflict".write(
            to: nested.appendingPathComponent("note.md.conflict1"),
            atomically: true,
            encoding: .utf8
        )

        let conflicts = try await sut.scanForConflicts(in: tempDir.path)

        XCTAssertEqual(conflicts.count, 1)
    }

    func testResolveKeepOriginal() throws {
        let original = tempDir.appendingPathComponent("note.md")
        let conflict = tempDir.appendingPathComponent("note.conflict1.md")
        try "original".write(to: original, atomically: true, encoding: .utf8)
        try "conflict".write(to: conflict, atomically: true, encoding: .utf8)

        let conflictFile = ConflictFile(
            originalPath: original.path,
            conflictPath: conflict.path
        )

        try sut.resolveConflict(conflictFile, resolution: .keepOriginal)

        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: conflict.path))
    }

    func testResolveKeepConflict() throws {
        let original = tempDir.appendingPathComponent("note.md")
        let conflict = tempDir.appendingPathComponent("note.conflict1.md")
        try "original".write(to: original, atomically: true, encoding: .utf8)
        try "conflict".write(to: conflict, atomically: true, encoding: .utf8)

        let conflictFile = ConflictFile(
            originalPath: original.path,
            conflictPath: conflict.path
        )

        try sut.resolveConflict(conflictFile, resolution: .keepConflict)

        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: conflict.path))
        let content = try String(contentsOfFile: original.path, encoding: .utf8)
        XCTAssertEqual(content, "conflict")
    }
}
