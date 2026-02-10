import Foundation

/// Represents a tag from the PKM vault
struct Tag: Identifiable, Codable, Hashable, Sendable {
    /// The unique identifier of the tag (derived from name)
    let id: String

    /// The display name of the tag
    let name: String

    /// Number of documents with this tag
    let documentCount: Int

    private enum CodingKeys: String, CodingKey {
        case name
        case documentCount = "count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        documentCount = try container.decode(Int.self, forKey: .documentCount)
        id = name
    }

    init(id: String, name: String, documentCount: Int) {
        self.id = id
        self.name = name
        self.documentCount = documentCount
    }
}
