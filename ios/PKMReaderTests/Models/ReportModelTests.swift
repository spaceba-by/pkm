import XCTest
@testable import PKMReader

final class ReportModelTests: XCTestCase {
    func test_report_identifiable() {
        let report = TestFixtures.sampleReport
        XCTAssertEqual(report.id, "_agent/reports/2024-01-01.md")
    }

    func test_report_weekOf() {
        let report = TestFixtures.sampleReport
        XCTAssertEqual(report.weekOf, "2024-01-01")
    }

    func test_report_optionalModified() {
        let report = Report(id: "test", weekOf: "2024-01-01")
        XCTAssertNil(report.modified)
    }

    func test_report_codable() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(TestFixtures.sampleReport)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Report.self, from: data)

        XCTAssertEqual(decoded.id, TestFixtures.sampleReport.id)
        XCTAssertEqual(decoded.weekOf, TestFixtures.sampleReport.weekOf)
    }
}
