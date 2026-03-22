@testable import PKMReader
import XCTest

final class DocumentSortOrderTests: XCTestCase {
    func test_modifiedDate_displayName() {
        XCTAssertEqual(DocumentSortOrder.modifiedDate.displayName, "Modified Date")
    }

    func test_createdDate_displayName() {
        XCTAssertEqual(DocumentSortOrder.createdDate.displayName, "Created Date")
    }

    func test_allCases_containsBothValues() {
        XCTAssertEqual(DocumentSortOrder.allCases.count, 2)
        XCTAssertTrue(DocumentSortOrder.allCases.contains(.modifiedDate))
        XCTAssertTrue(DocumentSortOrder.allCases.contains(.createdDate))
    }

    func test_rawValues() {
        XCTAssertEqual(DocumentSortOrder.modifiedDate.rawValue, "modifiedDate")
        XCTAssertEqual(DocumentSortOrder.createdDate.rawValue, "createdDate")
    }
}
