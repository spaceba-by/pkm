import Foundation

/// A node in the knowledge graph
struct GraphNode: Identifiable, Codable, Hashable, Sendable {
    /// Unique node identifier (e.g., "doc:notes/test.md", "entity:people:alice", "tag:swift")
    let id: String

    /// Node type: "document", "entity", or "tag"
    let type: String

    /// Display label for the node
    let label: String

    /// Document path (only for document nodes)
    let path: String?

    /// Document classification (only for document nodes)
    let classification: String?

    /// Entity type (only for entity nodes)
    let entityType: String?
}

/// An edge in the knowledge graph
struct GraphEdge: Codable, Hashable, Sendable {
    /// Source node ID
    let source: String

    /// Target node ID
    let target: String

    /// Edge type: "mentions", "tagged", "links_to", "co_occurrence"
    let type: String

    /// Edge weight (higher = stronger relationship)
    let weight: Int
}

/// Response from the graph data API
struct GraphDataResponse: Codable, Sendable {
    /// All nodes in the graph
    let nodes: [GraphNode]

    /// All edges in the graph
    let edges: [GraphEdge]

    /// Total node count
    let nodeCount: Int

    /// Total edge count
    let edgeCount: Int
}
