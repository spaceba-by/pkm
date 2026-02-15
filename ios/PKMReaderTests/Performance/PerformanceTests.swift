import XCTest
@testable import PKMReader

/// Performance benchmarks for critical operations in PKMReader
final class PerformanceTests: XCTestCase {

    // MARK: - JSON Decoding Performance

    func test_documentListDecoding_performance() throws {
        let documents = (0..<200).map { index in
            Self.makeDocumentJSON(index: index)
        }
        let responseJSON: [String: Any] = [
            "documents": documents,
            "nextCursor": NSNull()
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: responseJSON)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<10 {
                _ = try? decoder.decode(DocumentListResponse.self, from: jsonData)
            }
        }
    }

    func test_singleDocumentDecoding_performance() throws {
        let docJSON = Self.makeDocumentJSON(index: 0, includeContent: true)
        let jsonData = try JSONSerialization.data(withJSONObject: docJSON)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<100 {
                _ = try? decoder.decode(Document.self, from: jsonData)
            }
        }
    }

    // MARK: - JSON Encoding Performance

    func test_documentEncoding_performance() throws {
        let documents = (0..<200).map { index in
            Self.makeDocument(index: index)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<10 {
                _ = try? encoder.encode(documents)
            }
        }
    }

    // MARK: - Cache Service Performance

    @MainActor
    func test_cacheWrite_performance() throws {
        let cacheService = try DocumentCacheService(inMemory: true)
        let documents = (0..<100).map { index in
            Self.makeDocument(index: index)
        }

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            cacheService.cacheDocuments(documents)
        }
    }

    @MainActor
    func test_cacheRead_performance() throws {
        let cacheService = try DocumentCacheService(inMemory: true)
        let documents = (0..<100).map { index in
            Self.makeDocument(index: index)
        }
        cacheService.cacheDocuments(documents)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = cacheService.getCachedDocuments(classification: nil)
        }
    }

    @MainActor
    func test_cacheReadFiltered_performance() throws {
        let cacheService = try DocumentCacheService(inMemory: true)
        let documents = (0..<100).map { index in
            Self.makeDocument(index: index)
        }
        cacheService.cacheDocuments(documents)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = cacheService.getCachedDocuments(classification: .meeting)
        }
    }

    @MainActor
    func test_cacheLookupById_performance() throws {
        let cacheService = try DocumentCacheService(inMemory: true)
        let documents = (0..<100).map { index in
            Self.makeDocument(index: index)
        }
        cacheService.cacheDocuments(documents)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for i in 0..<100 {
                _ = cacheService.getCachedDocument(id: "docs/document-\(i).md")
            }
        }
    }

    // MARK: - Search Filtering Performance

    @MainActor
    func test_searchDebounce_cancellation_performance() {
        let mockAPIClient = MockAPIClient()
        mockAPIClient.searchResult = .success([])
        let viewModel = SearchViewModel(apiClient: mockAPIClient)

        measure(metrics: [XCTClockMetric()]) {
            for i in 0..<50 {
                viewModel.searchText = String(repeating: "a", count: i + 2)
            }
        }
    }

    // MARK: - Markdown Content Processing Performance

    func test_largeMarkdownStringProcessing_performance() {
        let markdown = Self.generateMarkdown(paragraphs: 50)
        let documentJSON: [String: Any] = [
            "id": "docs/large-document.md",
            "title": "Large Document",
            "content": markdown,
            "metadata": [
                "classification": "reference",
                "tags": ["test", "performance", "markdown"],
                "linksTo": (0..<20).map { "docs/link-\($0).md" },
                "entities": [
                    "people": ["Alice", "Bob", "Charlie"],
                    "organizations": ["Acme Corp", "Test Inc"],
                    "concepts": ["performance", "benchmarking", "optimization"],
                    "locations": ["New York", "London"]
                ],
                "created": "2024-01-01T00:00:00Z",
                "modified": "2024-06-15T12:00:00Z",
                "hasFrontmatter": true
            ] as [String: Any]
        ]

        let jsonData = try! JSONSerialization.data(withJSONObject: documentJSON) // swiftlint:disable:this force_try
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<50 {
                _ = try? decoder.decode(Document.self, from: jsonData)
            }
        }
    }

    // MARK: - Batch Operations Performance

    func test_documentSorting_performance() {
        let documents = (0..<500).map { index in
            Self.makeDocument(index: index)
        }

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<10 {
                _ = documents.sorted { $0.metadata.modified > $1.metadata.modified }
            }
        }
    }

    func test_documentFilterByClassification_performance() {
        let documents = (0..<500).map { index in
            Self.makeDocument(index: index)
        }

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<10 {
                _ = documents.filter { $0.metadata.classification == .meeting }
            }
        }
    }

    func test_documentFilterByTag_performance() {
        let documents = (0..<500).map { index in
            Self.makeDocument(index: index)
        }

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<10 {
                _ = documents.filter { $0.metadata.tags.contains("tag-3") }
            }
        }
    }
}

// MARK: - Test Data Generators

extension PerformanceTests {
    private static let classifications: [String] = ["meeting", "idea", "reference", "journal", "project"]

    static func makeDocumentJSON(index: Int, includeContent: Bool = false) -> [String: Any] {
        let classification = classifications[index % classifications.count]
        var json: [String: Any] = [
            "id": "docs/document-\(index).md",
            "title": "Document \(index) - Performance Test",
            "metadata": [
                "classification": classification,
                "tags": ["tag-\(index % 10)", "perf-test", "batch-\(index / 50)"],
                "linksTo": ["docs/other-\(index).md"],
                "created": "2024-01-\(String(format: "%02d", (index % 28) + 1))T00:00:00Z",
                "modified": "2024-06-\(String(format: "%02d", (index % 28) + 1))T12:00:00Z",
                "hasFrontmatter": true
            ] as [String: Any]
        ]
        if includeContent {
            json["content"] = "# Document \(index)\n\nThis is test content for document \(index).\n\n" +
                "It contains multiple paragraphs for testing purposes."
        }
        return json
    }

    static func makeDocument(index: Int) -> Document {
        let allClassifications = DocumentClassification.allCases
        Document(
            id: "docs/document-\(index).md",
            title: "Document \(index) - Performance Test",
            content: nil,
            metadata: DocumentMetadata(
                classification: allClassifications[index % allClassifications.count],
                tags: ["tag-\(index % 10)", "perf-test", "batch-\(index / 50)"],
                linksTo: ["docs/other-\(index).md"],
                entities: nil,
                created: Date(timeIntervalSince1970: 1_704_067_200 + Double(index * 86400)),
                modified: Date(timeIntervalSince1970: 1_718_452_800 + Double(index * 86400)),
                hasFrontmatter: true
            )
        )
    }

    static func generateMarkdown(paragraphs: Int) -> String {
        var lines: [String] = ["# Performance Test Document", ""]
        for i in 0..<paragraphs {
            lines.append("## Section \(i + 1)")
            lines.append("")
            lines.append(
                "This is paragraph \(i + 1) of the test document. " +
                "It contains enough text to simulate a real document. " +
                "Links like [[other-doc]] and tags like #performance appear here. " +
                "People such as **Alice** and **Bob** are mentioned regularly."
            )
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
