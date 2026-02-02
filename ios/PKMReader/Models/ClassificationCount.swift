import Foundation

/// Count of documents per classification
struct ClassificationCount: Codable, Sendable {
    /// The classification name
    let name: String

    /// Display-friendly name
    let displayName: String

    /// Number of documents
    let count: Int

    /// SF Symbol icon name
    let icon: String
}
