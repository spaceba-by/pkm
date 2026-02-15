import XCTest
@testable import PKMReader

final class TagModelTests: XCTestCase {
    func test_tag_identifiable() {
        let tag = Tag(id: "swift", name: "swift", documentCount: 4)
        XCTAssertEqual(tag.id, "swift")
    }

    func test_tag_hashable() {
        let tag1 = Tag(id: "swift", name: "swift", documentCount: 4)
        let tag2 = Tag(id: "swift", name: "swift", documentCount: 4)
        XCTAssertEqual(tag1, tag2)
    }

    func test_tag_decodesFromJSON() throws {
        let json = Data("""
        {"name": "meeting", "count": 5}
        """.utf8)

        let tag = try JSONDecoder().decode(Tag.self, from: json)
        XCTAssertEqual(tag.name, "meeting")
        XCTAssertEqual(tag.documentCount, 5)
        XCTAssertEqual(tag.id, "meeting")
    }

    func test_tag_encodesAndDecodes() throws {
        let tag = Tag(id: "test", name: "test", documentCount: 3)
        let data = try JSONEncoder().encode(tag)
        let decoded = try JSONDecoder().decode(Tag.self, from: data)
        XCTAssertEqual(decoded.name, tag.name)
        XCTAssertEqual(decoded.documentCount, tag.documentCount)
    }
}
