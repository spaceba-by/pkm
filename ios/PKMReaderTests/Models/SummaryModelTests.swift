import XCTest
@testable import PKMReader

final class SummaryModelTests: XCTestCase {
    func test_summary_identifiable() {
        let summary = TestFixtures.sampleSummary
        XCTAssertEqual(summary.id, "_agent/summaries/2024-01-01.md")
    }

    func test_summary_date() {
        let summary = TestFixtures.sampleSummary
        XCTAssertEqual(summary.date, "2024-01-01")
    }

    func test_summary_optionalModified() {
        let summary = Summary(id: "test", date: "2024-01-01")
        XCTAssertNil(summary.modified)
    }

    func test_summary_codable() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(TestFixtures.sampleSummary)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Summary.self, from: data)

        XCTAssertEqual(decoded.id, TestFixtures.sampleSummary.id)
        XCTAssertEqual(decoded.date, TestFixtures.sampleSummary.date)
    }
}
