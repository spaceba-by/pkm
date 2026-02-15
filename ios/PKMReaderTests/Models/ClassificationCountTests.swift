import XCTest
@testable import PKMReader

final class ClassificationCountTests: XCTestCase {
    func test_classificationCount_properties() {
        let count = ClassificationCount(
            name: "meeting",
            displayName: "Meeting",
            count: 5,
            icon: "person.3"
        )
        XCTAssertEqual(count.name, "meeting")
        XCTAssertEqual(count.displayName, "Meeting")
        XCTAssertEqual(count.count, 5)
        XCTAssertEqual(count.icon, "person.3")
    }

    func test_classificationCount_codable() throws {
        let original = ClassificationCount(
            name: "idea",
            displayName: "Idea",
            count: 3,
            icon: "lightbulb"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClassificationCount.self, from: data)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.count, original.count)
        XCTAssertEqual(decoded.icon, original.icon)
    }
}
