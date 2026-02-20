#if DEBUG
import Foundation

/// Mock API client that returns fixture data for UI testing
/// Activated via the `--mock-api` launch argument
final class UITestAPIClient: APIClientProtocol, @unchecked Sendable {
    // MARK: - Fixture Data

    private let fixtureDocuments: [Document] = [
        Document(
            id: "notes/meeting-notes.md",
            title: "Team Meeting Notes",
            content: """
                # Team Meeting Notes

                Attendees: Alice, Bob, Charlie

                ## Agenda
                - Project status update
                - Sprint planning
                - Action items review
                """,
            metadata: DocumentMetadata(
                classification: .meeting,
                tags: ["meeting", "team", "weekly"],
                linksTo: [],
                entities: DocumentEntities(
                    people: ["Alice", "Bob", "Charlie"],
                    organizations: nil,
                    concepts: ["sprint planning"],
                    locations: nil
                ),
                created: Date(timeIntervalSince1970: 1_704_067_200),
                modified: Date(timeIntervalSince1970: 1_704_067_200),
                hasFrontmatter: true
            )
        ),
        Document(
            id: "ideas/app-redesign.md",
            title: "App Redesign Ideas",
            content: """
                # App Redesign Ideas

                Consider a fresh look with:
                - New color scheme
                - Improved navigation
                - Dark mode support
                """,
            metadata: DocumentMetadata(
                classification: .idea,
                tags: ["idea", "design", "app"],
                linksTo: [],
                entities: nil,
                created: Date(timeIntervalSince1970: 1_704_153_600),
                modified: Date(timeIntervalSince1970: 1_704_153_600),
                hasFrontmatter: false
            )
        ),
        Document(
            id: "reference/swift-concurrency.md",
            title: "Swift Concurrency Guide",
            content: """
                # Swift Concurrency Guide

                ## async/await
                Swift concurrency model uses structured concurrency.

                ## Actors
                Actors provide data isolation.
                """,
            metadata: DocumentMetadata(
                classification: .reference,
                tags: ["swift", "concurrency", "reference"],
                linksTo: [],
                entities: nil,
                created: Date(timeIntervalSince1970: 1_704_240_000),
                modified: Date(timeIntervalSince1970: 1_704_240_000),
                hasFrontmatter: true
            )
        )
    ]

    private let fixtureTags: [Tag] = [
        Tag(id: "meeting", name: "meeting", documentCount: 5),
        Tag(id: "idea", name: "idea", documentCount: 3),
        Tag(id: "reference", name: "reference", documentCount: 8),
        Tag(id: "swift", name: "swift", documentCount: 4)
    ]

    private var fixtureSummaries: [Summary] {
        // Generate summaries for today and a few recent days so the calendar always has data
        let calendar = Calendar.current
        let today = Date()
        var summaries: [Summary] = []
        for offset in [0, -1, -2, -5, -8, -12] {
            if let date = calendar.date(byAdding: .day, value: offset, to: today) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let dateStr = formatter.string(from: date)
                summaries.append(Summary(
                    id: "_agent/summaries/\(dateStr).md",
                    date: dateStr,
                    modified: date
                ))
            }
        }
        return summaries
    }

    private var fixtureReports: [Report] {
        // Generate reports for the current week and the previous week
        let calendar = Calendar.current
        let today = Date()
        var reports: [Report] = []
        for weekOffset in [0, -1] {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: today) {
                // Find the Monday of that week
                let weekday = calendar.component(.weekday, from: weekStart)
                let daysToMonday = (weekday == 1) ? -6 : 2 - weekday
                if let monday = calendar.date(byAdding: .day, value: daysToMonday, to: weekStart) {
                    let isoFormatter = DateFormatter()
                    isoFormatter.dateFormat = "YYYY-'W'ww"
                    isoFormatter.calendar = Calendar(identifier: .iso8601)
                    isoFormatter.locale = Locale(identifier: "en_US_POSIX")
                    isoFormatter.timeZone = calendar.timeZone
                    let weekStr = isoFormatter.string(from: monday)
                    reports.append(Report(
                        id: "_agent/reports/weekly/\(weekStr).md",
                        weekOf: weekStr,
                        modified: monday
                    ))
                }
            }
        }
        return reports
    }

    // MARK: - APIClientProtocol

    func listDocuments(
        classification: DocumentClassification?,
        limit: Int,
        cursor: String?
    ) async throws -> DocumentListResponse {
        let filtered: [Document]
        if let classification {
            filtered = fixtureDocuments.filter { $0.metadata.classification == classification }
        } else {
            filtered = fixtureDocuments
        }
        return DocumentListResponse(documents: filtered, nextCursor: nil)
    }

    func getDocument(key: String) async throws -> Document {
        if let document = fixtureDocuments.first(where: { $0.id == key }) {
            return document
        }
        // For insight detail views, return a document with markdown content
        return Document(
            id: key,
            title: key,
            content: "# Content\n\nThis is the content for **\(key)**.\n\n- Item 1\n- Item 2\n- Item 3",
            metadata: DocumentMetadata(
                classification: .reference,
                tags: [],
                linksTo: [],
                entities: nil,
                created: Date(),
                modified: Date(),
                hasFrontmatter: false
            )
        )
    }

    func search(query: String, limit: Int, mode: SearchMode = .keyword) async throws -> [Document] {
        fixtureDocuments.filter { document in
            document.title.localizedCaseInsensitiveContains(query) ||
            document.metadata.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    func listTags() async throws -> [Tag] {
        fixtureTags
    }

    func listClassifications() async throws -> [ClassificationCount] {
        [
            ClassificationCount(name: "meeting", displayName: "Meeting", count: 5, icon: "person.3"),
            ClassificationCount(name: "idea", displayName: "Idea", count: 3, icon: "lightbulb"),
            ClassificationCount(name: "reference", displayName: "Reference", count: 8, icon: "book")
        ]
    }

    func listSummaries(limit: Int) async throws -> [Summary] {
        fixtureSummaries
    }

    func listReports(limit: Int) async throws -> [Report] {
        fixtureReports
    }

    func documentsByTag(tag: String, limit: Int) async throws -> [Document] {
        fixtureDocuments.filter { $0.metadata.tags.contains(tag) }
    }

    func updateClassification(documentId: String, classification: DocumentClassification) async throws {
        // No-op for UI tests
    }

    func createDocument(key: String, title: String?, content: String) async throws -> CreateDocumentResponse {
        CreateDocumentResponse(key: key, title: title ?? key, createdAt: "2024-01-01T00:00:00Z")
    }

    func updateDocument(key: String, content: String, ifUnmodifiedSince: String?) async throws {
        // No-op for UI tests
    }

    func deleteDocument(key: String) async throws {
        // No-op for UI tests
    }

    func getGraphData() async throws -> GraphDataResponse {
        let nodes = Self.fixtureGraphNodes
        let edges = Self.fixtureGraphEdges
        return GraphDataResponse(nodes: nodes, edges: edges, nodeCount: nodes.count, edgeCount: edges.count)
    }

    // swiftlint:disable line_length
    private static let fixtureGraphNodes: [GraphNode] = [
        GraphNode(id: "doc:notes/meeting-notes.md", type: "document", label: "Team Meeting Notes", path: "notes/meeting-notes.md", classification: "meeting", entityType: nil),
        GraphNode(id: "doc:ideas/app-redesign.md", type: "document", label: "App Redesign Ideas", path: "ideas/app-redesign.md", classification: "idea", entityType: nil),
        GraphNode(id: "doc:reference/swift-concurrency.md", type: "document", label: "Swift Concurrency Guide", path: "reference/swift-concurrency.md", classification: "reference", entityType: nil),
        GraphNode(id: "entity:people:alice", type: "entity", label: "Alice", path: nil, classification: nil, entityType: "people"),
        GraphNode(id: "entity:people:bob", type: "entity", label: "Bob", path: nil, classification: nil, entityType: "people"),
        GraphNode(id: "entity:concepts:sprint planning", type: "entity", label: "Sprint Planning", path: nil, classification: nil, entityType: "concepts"),
        GraphNode(id: "tag:meeting", type: "tag", label: "meeting", path: nil, classification: nil, entityType: nil),
        GraphNode(id: "tag:swift", type: "tag", label: "swift", path: nil, classification: nil, entityType: nil),
        GraphNode(id: "tag:design", type: "tag", label: "design", path: nil, classification: nil, entityType: nil)
    ]

    private static let fixtureGraphEdges: [GraphEdge] = [
        GraphEdge(source: "doc:notes/meeting-notes.md", target: "entity:people:alice", type: "mentions", weight: 1),
        GraphEdge(source: "doc:notes/meeting-notes.md", target: "entity:people:bob", type: "mentions", weight: 1),
        GraphEdge(source: "doc:notes/meeting-notes.md", target: "entity:concepts:sprint planning", type: "mentions", weight: 1),
        GraphEdge(source: "doc:notes/meeting-notes.md", target: "tag:meeting", type: "tagged", weight: 1),
        GraphEdge(source: "doc:ideas/app-redesign.md", target: "tag:design", type: "tagged", weight: 1),
        GraphEdge(source: "doc:reference/swift-concurrency.md", target: "tag:swift", type: "tagged", weight: 1),
        GraphEdge(source: "entity:people:alice", target: "entity:people:bob", type: "co_occurrence", weight: 1)
    ]
    // swiftlint:enable line_length
}

#endif
