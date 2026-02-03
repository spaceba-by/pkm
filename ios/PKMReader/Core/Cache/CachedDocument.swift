import Foundation
import SwiftData

/// SwiftData model for caching document metadata locally
@Model
final class CachedDocument {
    /// The unique identifier (S3 key) of the document
    @Attribute(.unique)
    var id: String

    /// The title of the document
    var title: String

    /// The markdown content (cached on demand)
    var content: String?

    /// Classification as raw string
    var classification: String

    /// Tags as JSON-encoded array
    var tagsJSON: String

    /// When the document was created
    var created: Date

    /// When the document was last modified
    var modified: Date

    /// When this cache entry was last updated
    var cachedAt: Date

    init(
        id: String,
        title: String,
        content: String?,
        classification: String,
        tagsJSON: String,
        created: Date,
        modified: Date,
        cachedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.classification = classification
        self.tagsJSON = tagsJSON
        self.created = created
        self.modified = modified
        self.cachedAt = cachedAt
    }

    convenience init(from document: Document) {
        let tagsData = (try? JSONEncoder().encode(document.metadata.tags)) ?? Data()
        let tagsString = String(data: tagsData, encoding: .utf8) ?? "[]"

        self.init(
            id: document.id,
            title: document.title,
            content: document.content,
            classification: document.metadata.classification.rawValue,
            tagsJSON: tagsString,
            created: document.metadata.created,
            modified: document.metadata.modified
        )
    }

    /// Convert back to a Document
    func toDocument() -> Document {
        let tags = (try? JSONDecoder().decode(
            [String].self,
            from: tagsJSON.data(using: .utf8) ?? Data()
        )) ?? []

        return Document(
            id: id,
            title: title,
            content: content,
            metadata: DocumentMetadata(
                classification: DocumentClassification(rawValue: classification) ?? .reference,
                tags: tags,
                linksTo: [],
                entities: nil,
                created: created,
                modified: modified,
                hasFrontmatter: false
            )
        )
    }
}
