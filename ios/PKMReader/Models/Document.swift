import Foundation

/// Represents a document from the PKM vault
struct Document: Identifiable, Codable, Hashable, Sendable {
    /// The unique identifier (S3 key) of the document
    let id: String

    /// The title of the document
    let title: String

    /// The markdown content of the document (optional, loaded on demand)
    let content: String?

    /// Metadata associated with the document
    let metadata: DocumentMetadata

    /// Display-friendly title, falling back to "Untitled" if empty
    var displayTitle: String {
        title.isEmpty ? "Untitled" : title
    }
}

/// Metadata associated with a document
struct DocumentMetadata: Codable, Hashable, Sendable {
    /// The AI-assigned classification of the document
    let classification: DocumentClassification

    /// Tags associated with the document
    let tags: [String]

    /// Links to other documents
    let linksTo: [String]

    /// Extracted entities from the document
    let entities: DocumentEntities?

    /// When the document was created
    let created: Date

    /// When the document was last modified
    let modified: Date

    /// Whether the document has YAML frontmatter
    let hasFrontmatter: Bool
}

/// AI-assigned classification for documents
enum DocumentClassification: String, Codable, CaseIterable, Sendable {
    case meeting
    case idea
    case reference
    case journal
    case project

    /// Display-friendly name for the classification
    var displayName: String {
        rawValue.capitalized
    }

    /// SF Symbol icon name for the classification
    var icon: String {
        switch self {
        case .meeting: "person.3"
        case .idea: "lightbulb"
        case .reference: "book"
        case .journal: "book.closed"
        case .project: "folder"
        }
    }
}

/// Entities extracted from a document by AI
struct DocumentEntities: Codable, Hashable, Sendable {
    /// People mentioned in the document
    let people: [String]?

    /// Organizations mentioned in the document
    let organizations: [String]?

    /// Concepts discussed in the document
    let concepts: [String]?

    /// Locations mentioned in the document
    let locations: [String]?
}

/// Response from the list documents API
struct DocumentListResponse: Codable, Sendable {
    /// List of documents
    let documents: [Document]

    /// Cursor for pagination (nil if no more pages)
    let nextCursor: String?
}
