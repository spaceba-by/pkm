import Foundation
@testable import PKMReader

/// Provides sample test data for unit tests
enum TestFixtures {
    // MARK: - JSON Loading

    /// Load a JSON fixture file and decode it
    /// - Parameter filename: The name of the JSON file (without extension)
    /// - Returns: The decoded object
    static func loadJSON<T: Decodable>(_ filename: String) -> T {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            fatalError("Missing fixture file: \(filename).json")
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            fatalError("Failed to decode \(filename).json: \(error)")
        }
    }

    // MARK: - Sample Documents

    /// A sample document for testing
    static var sampleDocument: Document {
        Document(
            id: "test/sample.md",
            title: "Sample Document",
            content: "# Sample\n\nThis is a test document.",
            metadata: DocumentMetadata(
                classification: .reference,
                tags: ["test", "sample"],
                linksTo: [],
                entities: nil,
                created: Date(timeIntervalSince1970: 1_704_240_000), // 2024-01-03 (created newest)
                modified: Date(timeIntervalSince1970: 1_704_067_200), // 2024-01-01 (modified oldest)
                hasFrontmatter: true
            )
        )
    }

    /// A sample meeting document
    static var sampleMeetingDocument: Document {
        Document(
            id: "meetings/weekly.md",
            title: "Weekly Meeting",
            content: "# Weekly Meeting\n\nAttendees: John Doe, Jane Smith",
            metadata: DocumentMetadata(
                classification: .meeting,
                tags: ["meeting", "weekly"],
                linksTo: [],
                entities: DocumentEntities(
                    people: ["John Doe", "Jane Smith"],
                    organizations: nil,
                    concepts: nil,
                    locations: nil
                ),
                created: Date(timeIntervalSince1970: 1_704_153_600), // 2024-01-02
                modified: Date(timeIntervalSince1970: 1_704_153_600),
                hasFrontmatter: true
            )
        )
    }

    /// A sample idea document
    static var sampleIdeaDocument: Document {
        Document(
            id: "ideas/new-feature.md",
            title: "New Feature Idea",
            content: "# New Feature Idea\n\nThis is an idea for a new feature.",
            metadata: DocumentMetadata(
                classification: .idea,
                tags: ["idea", "feature"],
                linksTo: [],
                entities: nil,
                created: Date(timeIntervalSince1970: 1_704_067_200), // 2024-01-01 (created oldest)
                modified: Date(timeIntervalSince1970: 1_704_240_000), // 2024-01-03 (modified newest)
                hasFrontmatter: false
            )
        )
    }

    /// An array of sample documents for list testing
    static var sampleDocuments: [Document] {
        [sampleDocument, sampleMeetingDocument, sampleIdeaDocument]
    }

    /// A sample document list response
    static var sampleDocumentListResponse: DocumentListResponse {
        DocumentListResponse(
            documents: sampleDocuments,
            nextCursor: nil
        )
    }

    /// A paginated document list response
    static var paginatedDocumentListResponse: DocumentListResponse {
        DocumentListResponse(
            documents: [sampleDocument],
            nextCursor: "next-page-token"
        )
    }

    /// An empty document list response
    static var emptyDocumentListResponse: DocumentListResponse {
        DocumentListResponse(documents: [], nextCursor: nil)
    }

    // MARK: - Sample Tags

    /// A sample tag
    static var sampleTag: Tag {
        Tag(id: "test", name: "test", documentCount: 5)
    }

    /// An array of sample tags
    static var sampleTags: [Tag] {
        [
            Tag(id: "test", name: "test", documentCount: 5),
            Tag(id: "meeting", name: "meeting", documentCount: 10),
            Tag(id: "idea", name: "idea", documentCount: 3),
            Tag(id: "project", name: "project", documentCount: 7),
        ]
    }

    // MARK: - Sample Summaries

    /// A sample summary
    static var sampleSummary: Summary {
        Summary(
            id: "_agent/summaries/2024-01-01.md",
            date: "2024-01-01",
            modified: Date(timeIntervalSince1970: 1_704_067_200)
        )
    }

    /// An array of sample summaries
    static var sampleSummaries: [Summary] {
        [
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
            ),
        ]
    }

    // MARK: - Sample Reports

    /// A sample report
    static var sampleReport: Report {
        Report(
            id: "_agent/reports/2024-01-01.md",
            weekOf: "2024-01-01",
            modified: Date(timeIntervalSince1970: 1_704_067_200)
        )
    }

    /// An array of sample reports (weekOf uses ISO week format YYYY-Www)
    static var sampleReports: [Report] {
        [
            Report(
                id: "_agent/reports/weekly/2024-W03.md",
                weekOf: "2024-W03",
                modified: Date(timeIntervalSince1970: 1_705_276_800)
            ),
            Report(
                id: "_agent/reports/weekly/2024-W02.md",
                weekOf: "2024-W02",
                modified: Date(timeIntervalSince1970: 1_704_672_000)
            ),
            Report(
                id: "_agent/reports/weekly/2024-W01.md",
                weekOf: "2024-W01",
                modified: Date(timeIntervalSince1970: 1_704_067_200)
            ),
        ]
    }

    // MARK: - Sample Tasks

    static var sampleTasks: [ExtractedTask] {
        [
            ExtractedTask(
                taskId: "t-00000001",
                description: "Review Q1 proposal",
                status: "open",
                marker: "checkbox",
                documentPath: "meetings/2024-01-03.md",
                priority: "high"
            ),
            ExtractedTask(
                taskId: "t-00000002",
                description: "Update project roadmap",
                status: "open",
                source: "ai",
                marker: "implicit",
                documentPath: "projects/roadmap.md",
                priority: "medium"
            ),
            ExtractedTask(
                taskId: "t-00000003",
                description: "Fix broken link in docs",
                status: "completed",
                marker: "todo",
                documentPath: "docs/README.md"
            ),
        ]
    }

    static var sampleTaskListResponse: TaskListResponse {
        TaskListResponse(tasks: sampleTasks, count: 3, nextCursor: nil)
    }

    static var sampleTaskStats: TaskStatsResponse {
        TaskStatsResponse(open: 2, completed: 1, total: 3)
    }

    // MARK: - Sample Dispatch Jobs

    static let fixtureDate = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01

    static var sampleDispatchJobs: [DispatchJob] {
        [
            DispatchJob(
                jobId: "job-001",
                status: "completed",
                agentType: "claude-code",
                taskDescription: "Refactor extract_metadata handler",
                contextPaths: ["lambda/functions/extract_metadata/handler.clj"],
                created: fixtureDate,
                updated: fixtureDate,
                startedAt: fixtureDate,
                completedAt: fixtureDate,
                error: nil,
                artifacts: ["result.md"],
                resultPath: "_agent/dispatch/job-001/result.md",
                ecsTaskArn: nil,
                claimedBy: nil,
                createdBy: nil
            ),
            DispatchJob(
                jobId: "job-002",
                status: "running",
                agentType: "claude-code",
                taskDescription: "Add unit tests for notification service",
                contextPaths: nil,
                created: fixtureDate,
                updated: fixtureDate,
                startedAt: fixtureDate,
                completedAt: nil,
                error: nil,
                artifacts: nil,
                resultPath: nil,
                ecsTaskArn: "arn:aws:ecs:us-east-1:123:task/abc",
                claimedBy: nil,
                createdBy: nil
            ),
            DispatchJob(
                jobId: "job-003",
                status: "failed",
                agentType: "claude-code",
                taskDescription: "Generate weekly summary report",
                contextPaths: nil,
                created: fixtureDate,
                updated: fixtureDate,
                startedAt: fixtureDate,
                completedAt: fixtureDate,
                error: "Container exited with code 1",
                artifacts: nil,
                resultPath: nil,
                ecsTaskArn: nil,
                claimedBy: nil,
                createdBy: nil
            ),
        ]
    }

    static var sampleJobListResponse: JobListResponse {
        JobListResponse(jobs: sampleDispatchJobs, count: 3, nextCursor: nil)
    }
}

/// Helper class to find the test bundle
private class BundleToken {}
