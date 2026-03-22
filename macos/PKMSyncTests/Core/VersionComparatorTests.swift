@testable import PKMSync
import XCTest

final class VersionComparatorTests: XCTestCase {
    // MARK: - SemanticVersion Parsing

    func testParsesSimpleVersion() {
        let v = SemanticVersion(string: "1.2.3")
        XCTAssertEqual(v?.major, 1)
        XCTAssertEqual(v?.minor, 2)
        XCTAssertEqual(v?.patch, 3)
    }

    func testParsesTwoPartVersion() {
        let v = SemanticVersion(string: "2.5")
        XCTAssertEqual(v?.major, 2)
        XCTAssertEqual(v?.minor, 5)
        XCTAssertEqual(v?.patch, 0)
    }

    func testParsesVersionWithVPrefix() {
        let v = SemanticVersion(string: "v1.0.1")
        XCTAssertEqual(v?.major, 1)
        XCTAssertEqual(v?.minor, 0)
        XCTAssertEqual(v?.patch, 1)
    }

    func testParsesVersionWithMacosPrefix() {
        let v = SemanticVersion(string: "macos-v1.3.0")
        XCTAssertEqual(v?.major, 1)
        XCTAssertEqual(v?.minor, 3)
        XCTAssertEqual(v?.patch, 0)
    }

    func testReturnsNilForInvalidVersion() {
        XCTAssertNil(SemanticVersion(string: ""))
        XCTAssertNil(SemanticVersion(string: "abc"))
        XCTAssertNil(SemanticVersion(string: "v"))
    }

    func testDescription() {
        let v = SemanticVersion(string: "macos-v2.1.5")
        XCTAssertEqual(v?.description, "2.1.5")
    }

    // MARK: - Comparison

    func testMajorVersionComparison() {
        XCTAssertTrue(VersionComparator.isNewer("2.0.0", than: "1.0.0"))
        XCTAssertFalse(VersionComparator.isNewer("1.0.0", than: "2.0.0"))
    }

    func testMinorVersionComparison() {
        XCTAssertTrue(VersionComparator.isNewer("1.1.0", than: "1.0.0"))
        XCTAssertFalse(VersionComparator.isNewer("1.0.0", than: "1.1.0"))
    }

    func testPatchVersionComparison() {
        XCTAssertTrue(VersionComparator.isNewer("1.0.1", than: "1.0.0"))
        XCTAssertFalse(VersionComparator.isNewer("1.0.0", than: "1.0.1"))
    }

    func testEqualVersions() {
        XCTAssertFalse(VersionComparator.isNewer("1.0.0", than: "1.0.0"))
    }

    func testComparisonWithPrefixes() {
        XCTAssertTrue(VersionComparator.isNewer("macos-v1.1.0", than: "1.0.0"))
        XCTAssertTrue(VersionComparator.isNewer("macos-v2.0.0", than: "v1.9.9"))
    }

    func testComparisonWithInvalidVersions() {
        XCTAssertFalse(VersionComparator.isNewer("abc", than: "1.0.0"))
        XCTAssertFalse(VersionComparator.isNewer("1.0.0", than: "abc"))
    }
}
