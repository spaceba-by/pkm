import Foundation

/// Represents a tag from the PKM vault
struct Tag: Identifiable, Codable, Hashable, Sendable {
    /// The unique identifier of the tag
    let id: String

    /// The display name of the tag
    let name: String

    /// Number of documents with this tag
    let documentCount: Int
}
