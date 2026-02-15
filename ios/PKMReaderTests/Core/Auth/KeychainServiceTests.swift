import XCTest
@testable import PKMReader

final class KeychainServiceTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var sut: KeychainService!
    // swiftlint:enable implicitly_unwrapped_optional
    private let testService = "by.spaceba.pkm.reader.tests"

    override func setUp() {
        super.setUp()
        sut = KeychainService(service: testService)
        // Clean up any leftover test data
        try? sut.delete(forKey: "test_key")
        try? sut.delete(forKey: "test_key_2")
    }

    override func tearDown() {
        try? sut.delete(forKey: "test_key")
        try? sut.delete(forKey: "test_key_2")
        sut = nil
        super.tearDown()
    }

    // MARK: - Save and Retrieve

    func test_saveAndRetrieve_success() throws {
        try sut.save("test_value", forKey: "test_key")
        let retrieved = try sut.retrieve(forKey: "test_key")
        XCTAssertEqual(retrieved, "test_value")
    }

    func test_retrieve_nonexistentKey_returnsNil() throws {
        let retrieved = try sut.retrieve(forKey: "nonexistent_key_\(UUID().uuidString)")
        XCTAssertNil(retrieved)
    }

    func test_save_overwritesExistingValue() throws {
        try sut.save("value1", forKey: "test_key")
        try sut.save("value2", forKey: "test_key")

        let retrieved = try sut.retrieve(forKey: "test_key")
        XCTAssertEqual(retrieved, "value2")
    }

    // MARK: - Delete

    func test_delete_removesValue() throws {
        try sut.save("test_value", forKey: "test_key")
        try sut.delete(forKey: "test_key")

        let retrieved = try sut.retrieve(forKey: "test_key")
        XCTAssertNil(retrieved)
    }

    func test_delete_nonexistentKey_doesNotThrow() throws {
        XCTAssertNoThrow(try sut.delete(forKey: "nonexistent_key_\(UUID().uuidString)"))
    }

    // MARK: - Multiple Keys

    func test_multipleKeys_independent() throws {
        try sut.save("value1", forKey: "test_key")
        try sut.save("value2", forKey: "test_key_2")

        XCTAssertEqual(try sut.retrieve(forKey: "test_key"), "value1")
        XCTAssertEqual(try sut.retrieve(forKey: "test_key_2"), "value2")

        try sut.delete(forKey: "test_key")
        XCTAssertNil(try sut.retrieve(forKey: "test_key"))
        XCTAssertEqual(try sut.retrieve(forKey: "test_key_2"), "value2")
    }
}
