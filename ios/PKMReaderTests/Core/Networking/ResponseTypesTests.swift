@testable import PKMReader
import XCTest

final class ResponseTypesTests: XCTestCase {
    // MARK: - SearchResponse

    func test_searchResponse_codable() throws {
        let response = SearchResponse(
            query: "test",
            results: [TestFixtures.sampleDocument],
            count: 1
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SearchResponse.self, from: data)

        XCTAssertEqual(decoded.query, "test")
        XCTAssertEqual(decoded.results.count, 1)
        XCTAssertEqual(decoded.count, 1)
    }

    // MARK: - TagListResponse

    func test_tagListResponse_codable() throws {
        let response = TagListResponse(
            tags: TestFixtures.sampleTags,
            count: TestFixtures.sampleTags.count
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TagListResponse.self, from: data)

        XCTAssertEqual(decoded.tags.count, TestFixtures.sampleTags.count)
        XCTAssertEqual(decoded.count, TestFixtures.sampleTags.count)
    }

    // MARK: - ClassificationListResponse

    func test_classificationListResponse_codable() throws {
        let classifications = [
            ClassificationCount(name: "meeting", displayName: "Meeting", count: 5, icon: "person.3"),
        ]
        let response = ClassificationListResponse(classifications: classifications)
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(ClassificationListResponse.self, from: data)

        XCTAssertEqual(decoded.classifications.count, 1)
        XCTAssertEqual(decoded.classifications.first?.name, "meeting")
    }

    // MARK: - SummaryListResponse

    func test_summaryListResponse_codable() throws {
        let response = SummaryListResponse(
            summaries: TestFixtures.sampleSummaries,
            count: TestFixtures.sampleSummaries.count
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SummaryListResponse.self, from: data)

        XCTAssertEqual(decoded.summaries.count, TestFixtures.sampleSummaries.count)
        XCTAssertEqual(decoded.count, TestFixtures.sampleSummaries.count)
    }

    // MARK: - ReportListResponse

    func test_reportListResponse_codable() throws {
        let response = ReportListResponse(
            reports: TestFixtures.sampleReports,
            count: TestFixtures.sampleReports.count
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ReportListResponse.self, from: data)

        XCTAssertEqual(decoded.reports.count, TestFixtures.sampleReports.count)
        XCTAssertEqual(decoded.count, TestFixtures.sampleReports.count)
    }

    // MARK: - DocumentsByTagResponse

    func test_documentsByTagResponse_codable() throws {
        let response = DocumentsByTagResponse(
            tag: "swift",
            documents: [TestFixtures.sampleDocument],
            count: 1
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DocumentsByTagResponse.self, from: data)

        XCTAssertEqual(decoded.tag, "swift")
        XCTAssertEqual(decoded.documents.count, 1)
        XCTAssertEqual(decoded.count, 1)
    }
}
