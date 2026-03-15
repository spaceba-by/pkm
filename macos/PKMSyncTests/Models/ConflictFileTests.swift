@testable import PKMSync
import XCTest

final class ConflictFileTests: XCTestCase {
    func testRelativePathWithMatchingVaultPath() {
        let conflict = ConflictFile(
            originalPath: "/Users/test/vault/people/kasisto.md",
            conflictPath: "/Users/test/vault/people/kasisto.conflict1.md"
        )

        XCTAssertEqual(conflict.relativePath(from: "/Users/test/vault"), "people/kasisto.md")
    }

    func testRelativePathWithTrailingSlash() {
        let conflict = ConflictFile(
            originalPath: "/Users/test/vault/people/kasisto.md",
            conflictPath: "/Users/test/vault/people/kasisto.conflict1.md"
        )

        XCTAssertEqual(conflict.relativePath(from: "/Users/test/vault/"), "people/kasisto.md")
    }

    func testRelativePathWithNoMatch() {
        let conflict = ConflictFile(
            originalPath: "/other/path/note.md",
            conflictPath: "/other/path/note.conflict1.md"
        )

        XCTAssertEqual(conflict.relativePath(from: "/Users/test/vault"), "note.md")
    }

    func testRelativePathAtVaultRoot() {
        let conflict = ConflictFile(
            originalPath: "/Users/test/vault/note.md",
            conflictPath: "/Users/test/vault/note.conflict1.md"
        )

        XCTAssertEqual(conflict.relativePath(from: "/Users/test/vault"), "note.md")
    }

    func testRelativePathDeeplyNested() {
        let conflict = ConflictFile(
            originalPath: "/Users/test/vault/a/b/c/deep.md",
            conflictPath: "/Users/test/vault/a/b/c/deep.conflict1.md"
        )

        XCTAssertEqual(conflict.relativePath(from: "/Users/test/vault"), "a/b/c/deep.md")
    }

    func testRelativePathWithSimilarPrefix() {
        let conflict = ConflictFile(
            originalPath: "/Users/test/vault2/note.md",
            conflictPath: "/Users/test/vault2/note.conflict1.md"
        )

        // "/Users/test/vault" is a string prefix of "/Users/test/vault2/note.md"
        // but not a path-component prefix — should fall back to filename
        XCTAssertEqual(conflict.relativePath(from: "/Users/test/vault"), "note.md")
    }
}
