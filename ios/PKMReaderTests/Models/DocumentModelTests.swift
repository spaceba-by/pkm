@testable import PKMReader
import XCTest

final class DocumentModelTests: XCTestCase {
    // MARK: - Document Tests

    func test_displayTitle_returnsTitle_whenNotEmpty() {
        let doc = Document(
            id: "test.md",
            title: "My Document",
            content: nil,
            metadata: TestFixtures.sampleDocument.metadata
        )
        XCTAssertEqual(doc.displayTitle, "My Document")
    }

    func test_displayTitle_returnsUntitled_whenEmpty() {
        let doc = Document(
            id: "test.md",
            title: "",
            content: nil,
            metadata: TestFixtures.sampleDocument.metadata
        )
        XCTAssertEqual(doc.displayTitle, "Untitled")
    }

    func test_document_identifiable_usesId() {
        let doc = TestFixtures.sampleDocument
        XCTAssertEqual(doc.id, "test/sample.md")
    }

    func test_document_hashable() {
        let doc1 = TestFixtures.sampleDocument
        let doc2 = TestFixtures.sampleDocument
        XCTAssertEqual(doc1, doc2)

        var set = Set<Document>()
        set.insert(doc1)
        set.insert(doc2)
        XCTAssertEqual(set.count, 1)
    }

    func test_document_codable_roundTrip() throws {
        let original = TestFixtures.sampleDocument
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Document.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.metadata.classification, original.metadata.classification)
        XCTAssertEqual(decoded.metadata.tags, original.metadata.tags)
    }

    // MARK: - DocumentClassification Tests

    func test_classification_displayName_isCapitalized() {
        XCTAssertEqual(DocumentClassification.meeting.displayName, "Meeting")
        XCTAssertEqual(DocumentClassification.idea.displayName, "Idea")
        XCTAssertEqual(DocumentClassification.reference.displayName, "Reference")
        XCTAssertEqual(DocumentClassification.journal.displayName, "Journal")
        XCTAssertEqual(DocumentClassification.project.displayName, "Project")
    }

    func test_classification_icon_returnsSFSymbol() {
        XCTAssertEqual(DocumentClassification.meeting.icon, "person.3")
        XCTAssertEqual(DocumentClassification.idea.icon, "lightbulb")
        XCTAssertEqual(DocumentClassification.reference.icon, "book")
        XCTAssertEqual(DocumentClassification.journal.icon, "book.closed")
        XCTAssertEqual(DocumentClassification.project.icon, "folder")
    }

    func test_classification_allCases_containsAll() {
        XCTAssertEqual(DocumentClassification.allCases.count, 5)
    }

    func test_classification_rawValue_roundTrip() {
        for classification in DocumentClassification.allCases {
            let raw = classification.rawValue
            let decoded = DocumentClassification(rawValue: raw)
            XCTAssertEqual(decoded, classification)
        }
    }

    // MARK: - DocumentEntities Tests

    func test_entities_codable() throws {
        let entities = DocumentEntities(
            people: ["Alice", "Bob"],
            organizations: ["Acme"],
            concepts: ["Testing"],
            locations: ["NYC"]
        )
        let data = try JSONEncoder().encode(entities)
        let decoded = try JSONDecoder().decode(DocumentEntities.self, from: data)
        XCTAssertEqual(decoded.people, ["Alice", "Bob"])
        XCTAssertEqual(decoded.organizations, ["Acme"])
        XCTAssertEqual(decoded.concepts, ["Testing"])
        XCTAssertEqual(decoded.locations, ["NYC"])
    }

    func test_entities_nilFields() throws {
        let entities = DocumentEntities(
            people: nil,
            organizations: nil,
            concepts: nil,
            locations: nil
        )
        let data = try JSONEncoder().encode(entities)
        let decoded = try JSONDecoder().decode(DocumentEntities.self, from: data)
        XCTAssertNil(decoded.people)
        XCTAssertNil(decoded.organizations)
        XCTAssertNil(decoded.concepts)
        XCTAssertNil(decoded.locations)
    }

    // MARK: - DocumentListResponse Tests

    func test_documentListResponse_codable() throws {
        let response = TestFixtures.paginatedDocumentListResponse
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DocumentListResponse.self, from: data)

        XCTAssertEqual(decoded.documents.count, response.documents.count)
        XCTAssertEqual(decoded.nextCursor, "next-page-token")
    }

    func test_documentListResponse_nilCursor() {
        let response = TestFixtures.emptyDocumentListResponse
        XCTAssertNil(response.nextCursor)
        XCTAssertTrue(response.documents.isEmpty)
    }
}
