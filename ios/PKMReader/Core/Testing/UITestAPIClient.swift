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

    private let fixtureSummaries: [Summary] = [
        Summary(
            id: "_agent/summaries/2024-01-03.md",
            date: "2024-01-03",
            modified: Date(timeIntervalSince1970: 1_704_240_000)
        ),
        Summary(
            id: "_agent/summaries/2024-01-02.md",
            date: "2024-01-02",
            modified: Date(timeIntervalSince1970: 1_704_153_600)
        ),
        Summary(
            id: "_agent/summaries/2024-01-01.md",
            date: "2024-01-01",
            modified: Date(timeIntervalSince1970: 1_704_067_200)
        )
    ]

    private let fixtureReports: [Report] = [
        Report(
            id: "_agent/reports/2024-01-15.md",
            weekOf: "2024-01-15",
            modified: Date(timeIntervalSince1970: 1_705_276_800)
        ),
        Report(
            id: "_agent/reports/2024-01-08.md",
            weekOf: "2024-01-08",
            modified: Date(timeIntervalSince1970: 1_704_672_000)
        )
    ]

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

    func search(query: String, limit: Int) async throws -> [Document] {
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
}
#endif
