@testable import PKMReader
import XCTest

final class CacheKeyTests: XCTestCase {
    func test_documentList_key() {
        XCTAssertEqual(CacheKey.documentList, "documents.list")
    }

    func test_tags_key() {
        XCTAssertEqual(CacheKey.tags, "tags.list")
    }

    func test_document_key_withId() {
        let key = CacheKey.document(id: "notes/test.md")
        XCTAssertEqual(key, "document.notes/test.md")
    }

    func test_documentsByTag_key() {
        let key = CacheKey.documentsByTag(tag: "swift")
        XCTAssertEqual(key, "documents.tag.swift")
    }

    func test_documentsByClassification_key() {
        let key = CacheKey.documentsByClassification(classification: .meeting)
        XCTAssertEqual(key, "documents.classification.meeting")
    }

    func test_documentsByClassification_allCases() {
        for classification in DocumentClassification.allCases {
            let key = CacheKey.documentsByClassification(classification: classification)
            XCTAssertTrue(key.hasPrefix("documents.classification."))
            XCTAssertTrue(key.hasSuffix(classification.rawValue))
        }
    }
}
