import XCTest

extension XCTestCase {
    /// Load JSON data from a file in the test bundle
    /// - Parameter filename: The name of the JSON file (without extension)
    /// - Returns: The JSON data
    func loadJSONData(_ filename: String) throws -> Data {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            throw NSError(
                domain: "TestError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing fixture: \(filename).json"]
            )
        }
        return try Data(contentsOf: url)
    }

    /// Load and decode JSON from a file in the test bundle
    /// - Parameter filename: The name of the JSON file (without extension)
    /// - Returns: The decoded object
    func loadJSON<T: Decodable>(_ filename: String) throws -> T {
        let data = try loadJSONData(filename)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    /// Encode an object to JSON data for comparison
    /// - Parameter value: The value to encode
    /// - Returns: The JSON data
    func encodeToJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(value)
    }

    /// Assert that two JSON representations are equal
    /// - Parameters:
    ///   - lhs: First JSON data
    ///   - rhs: Second JSON data
    ///   - message: Custom failure message
    func assertJSONEqual(_ lhs: Data, _ rhs: Data, _ message: String = "") {
        do {
            let lhsObject = try JSONSerialization.jsonObject(with: lhs)
            let rhsObject = try JSONSerialization.jsonObject(with: rhs)

            let lhsNormalized = try JSONSerialization.data(
                withJSONObject: lhsObject,
                options: .sortedKeys
            )
            let rhsNormalized = try JSONSerialization.data(
                withJSONObject: rhsObject,
                options: .sortedKeys
            )

            XCTAssertEqual(lhsNormalized, rhsNormalized, message)
        } catch {
            XCTFail("Failed to compare JSON: \(error)")
        }
    }
}
