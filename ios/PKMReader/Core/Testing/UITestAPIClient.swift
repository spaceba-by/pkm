// swiftlint:disable file_length
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
            ),
        ]

        private let fixtureTags: [Tag] = [
            Tag(id: "meeting", name: "meeting", documentCount: 5),
            Tag(id: "idea", name: "idea", documentCount: 3),
            Tag(id: "reference", name: "reference", documentCount: 8),
            Tag(id: "swift", name: "swift", documentCount: 4),
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
            limit _: Int,
            cursor _: String?,
            sort _: DocumentSortOrder? = nil
        ) async throws -> DocumentListResponse {
            let filtered: [Document] = if let classification {
                fixtureDocuments.filter { $0.metadata.classification == classification }
            } else {
                fixtureDocuments
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

        func search(query: String, limit _: Int, mode _: SearchMode = .keyword) async throws -> [Document] {
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
                ClassificationCount(name: "reference", displayName: "Reference", count: 8, icon: "book"),
            ]
        }

        func listSummaries(limit _: Int) async throws -> [Summary] {
            fixtureSummaries
        }

        func listReports(limit _: Int) async throws -> [Report] {
            fixtureReports
        }

        func documentsByTag(tag: String, limit _: Int) async throws -> [Document] {
            fixtureDocuments.filter { $0.metadata.tags.contains(tag) }
        }

        func updateClassification(documentId _: String, classification _: DocumentClassification) async throws {}

        func createDocument(key: String, title: String?, content _: String) async throws -> CreateDocumentResponse {
            CreateDocumentResponse(key: key, title: title ?? key, createdAt: "2024-01-01T00:00:00Z")
        }

        func updateDocument(key _: String, content _: String, ifUnmodifiedSince _: String?) async throws {}
        func deleteDocument(key _: String) async throws {}

        func getGraphData() async throws -> GraphDataResponse {
            let nodes = Self.fixtureGraphNodes
            let edges = Self.fixtureGraphEdges
            return GraphDataResponse(nodes: nodes, edges: edges, nodeCount: nodes.count, edgeCount: edges.count)
        }

        // MARK: - Search Monitors

        private let fixtureMonitors: [SearchMonitor] = [
            SearchMonitor(
                id: "monitor-1",
                name: "Swift Concurrency Updates",
                description: "Track Swift concurrency developments",
                searchTerms: ["swift concurrency", "async await", "structured concurrency"],
                intervalHours: 12,
                noveltyThreshold: 0.3,
                status: .active,
                lastExecuted: "2026-02-20T10:00:00Z",
                nextExecution: "2026-02-20T22:00:00Z",
                created: "2026-02-01T00:00:00Z",
                modified: "2026-02-20T10:00:00Z"
            ),
            SearchMonitor(
                id: "monitor-2",
                name: "AI Research",
                description: "Monitor AI research papers and news",
                searchTerms: ["large language models", "AI safety"],
                intervalHours: 24,
                noveltyThreshold: 0.5,
                status: .paused,
                lastExecuted: "2026-02-19T08:00:00Z",
                nextExecution: "2026-02-21T08:00:00Z",
                created: "2026-01-15T00:00:00Z",
                modified: "2026-02-19T08:00:00Z"
            ),
        ]

        private let fixtureSummariesForMonitor: [SearchSummary] = [
            SearchSummary(
                timestamp: "2026-02-20T10:00:00Z",
                summary: "New developments in Swift concurrency with isolation regions.",
                topics: ["Swift", "Concurrency", "Isolation"],
                noveltyScore: 0.7,
                significantUpdate: true,
                newItems: ["Isolation regions RFC", "Task executor improvements"],
                changedItems: ["Actor reentrancy proposal updated"],
                removedItems: [],
                analysis: "Significant progress on isolation regions for safer concurrency.",
                viewed: false
            ),
            SearchSummary(
                timestamp: "2026-02-19T10:00:00Z",
                summary: "Minor updates to async sequence proposals.",
                topics: ["Swift", "AsyncSequence"],
                noveltyScore: 0.2,
                significantUpdate: false,
                newItems: [],
                changedItems: ["AsyncSequence docs updated"],
                removedItems: [],
                analysis: nil
            ),
        ]

        func listSearchMonitors() async throws -> [SearchMonitor] {
            fixtureMonitors
        }

        func getSearchMonitor(id: String) async throws -> SearchMonitorDetailResponse {
            let monitor = fixtureMonitors.first { $0.id == id } ?? fixtureMonitors[0]
            return SearchMonitorDetailResponse(
                monitor: monitor,
                summaries: fixtureSummariesForMonitor,
                summaryCount: fixtureSummariesForMonitor.count
            )
        }

        func createSearchMonitor(request: SearchMonitorRequest) async throws -> SearchMonitor {
            SearchMonitor(
                id: "monitor-new",
                name: request.name ?? "",
                description: request.description ?? "",
                searchTerms: request.searchTerms ?? [],
                intervalHours: request.intervalHours ?? 6,
                noveltyThreshold: request.noveltyThreshold ?? 0.3,
                status: .active,
                lastExecuted: nil,
                nextExecution: "2026-02-21T00:00:00Z",
                created: "2026-02-20T12:00:00Z",
                modified: "2026-02-20T12:00:00Z"
            )
        }

        func updateSearchMonitor(id: String, request: SearchMonitorRequest) async throws -> SearchMonitor {
            let existing = fixtureMonitors.first { $0.id == id } ?? fixtureMonitors[0]
            return SearchMonitor(
                id: existing.id,
                name: request.name ?? existing.name,
                description: request.description ?? existing.description,
                searchTerms: request.searchTerms ?? existing.searchTerms,
                intervalHours: request.intervalHours ?? existing.intervalHours,
                noveltyThreshold: request.noveltyThreshold ?? existing.noveltyThreshold,
                status: request.status ?? existing.status,
                lastExecuted: existing.lastExecuted,
                nextExecution: existing.nextExecution,
                created: existing.created,
                modified: "2026-02-20T12:00:00Z"
            )
        }

        func deleteSearchMonitor(id _: String) async throws {}

        func listSearchMonitorSummaries(monitorId _: String, limit _: Int) async throws -> [SearchSummary] {
            fixtureSummariesForMonitor
        }

        func getSearchMonitorSummary(monitorId _: String, timestamp: String) async throws -> SearchSummary {
            fixtureSummariesForMonitor.first { $0.timestamp == timestamp } ?? fixtureSummariesForMonitor[0]
        }

        private static let fixtureGraphNodes: [GraphNode] = [
            GraphNode(
                id: "doc:notes/meeting-notes.md",
                type: "document",
                label: "Team Meeting Notes",
                path: "notes/meeting-notes.md",
                classification: "meeting",
                entityType: nil
            ),
            GraphNode(
                id: "doc:ideas/app-redesign.md",
                type: "document",
                label: "App Redesign Ideas",
                path: "ideas/app-redesign.md",
                classification: "idea",
                entityType: nil
            ),
            GraphNode(
                id: "doc:reference/swift-concurrency.md",
                type: "document",
                label: "Swift Concurrency Guide",
                path: "reference/swift-concurrency.md",
                classification: "reference",
                entityType: nil
            ),
            GraphNode(
                id: "entity:people:alice",
                type: "entity",
                label: "Alice",
                path: nil,
                classification: nil,
                entityType: "people"
            ),
            GraphNode(
                id: "entity:people:bob",
                type: "entity",
                label: "Bob",
                path: nil,
                classification: nil,
                entityType: "people"
            ),
            GraphNode(
                id: "entity:concepts:sprint planning",
                type: "entity",
                label: "Sprint Planning",
                path: nil,
                classification: nil,
                entityType: "concepts"
            ),
            GraphNode(
                id: "tag:meeting",
                type: "tag",
                label: "meeting",
                path: nil,
                classification: nil,
                entityType: nil
            ),
            GraphNode(id: "tag:swift", type: "tag", label: "swift", path: nil, classification: nil, entityType: nil),
            GraphNode(id: "tag:design", type: "tag", label: "design", path: nil, classification: nil, entityType: nil),
        ]

        private static let fixtureGraphEdges: [GraphEdge] = [
            GraphEdge(source: "doc:notes/meeting-notes.md", target: "entity:people:alice", type: "mentions", weight: 1),
            GraphEdge(source: "doc:notes/meeting-notes.md", target: "entity:people:bob", type: "mentions", weight: 1),
            GraphEdge(
                source: "doc:notes/meeting-notes.md",
                target: "entity:concepts:sprint planning",
                type: "mentions",
                weight: 1
            ),
            GraphEdge(source: "doc:notes/meeting-notes.md", target: "tag:meeting", type: "tagged", weight: 1),
            GraphEdge(source: "doc:ideas/app-redesign.md", target: "tag:design", type: "tagged", weight: 1),
            GraphEdge(source: "doc:reference/swift-concurrency.md", target: "tag:swift", type: "tagged", weight: 1),
            GraphEdge(source: "entity:people:alice", target: "entity:people:bob", type: "co_occurrence", weight: 1),
        ]

        // MARK: - Chat

        func sendChatMessage(message: String, conversationId: String?) async throws -> ChatSendResponse {
            ChatSendResponse(
                conversationId: conversationId ?? "fixture-conv-id",
                userMessage: ChatMessage(
                    id: "fixture-user-msg",
                    role: .user,
                    content: message,
                    timestamp: "2026-03-14T00:00:00Z",
                    status: .complete
                ),
                assistantMessageId: "fixture-assistant-msg"
            )
        }

        func listConversations() async throws -> [ChatConversation] {
            [
                ChatConversation(
                    id: "conv-1",
                    title: "What meetings happened...",
                    created: "2026-03-14T00:00:00Z",
                    modified: "2026-03-14T00:00:00Z",
                    messageCount: 2,
                    status: "active"
                ),
            ]
        }

        func getConversationMessages(conversationId _: String) async throws -> [ChatMessage] {
            [
                ChatMessage(
                    id: "msg-1",
                    role: .user,
                    content: "What meetings happened this week?",
                    timestamp: "2026-03-14T00:00:00Z",
                    status: .complete
                ),
                ChatMessage(
                    id: "msg-2",
                    role: .assistant,
                    content: "Based on your vault, you had 3 meetings this week...",
                    timestamp: "2026-03-14T00:00:01Z",
                    status: .complete
                ),
            ]
        }

        // MARK: - Device Tokens & Notifications

        func registerDevice(request: DeviceRegistrationRequest) async throws -> DeviceRegistrationResponse {
            DeviceRegistrationResponse(deviceId: request.deviceId, registered: true)
        }

        func unregisterDevice(deviceId _: String) async throws {}

        func listNotifications() async throws -> NotificationListResponse {
            let notifications = [
                PKMNotification(
                    notificationId: "notif-001",
                    notificationType: .dailySummary,
                    title: "Daily Summary: 2026-02-23",
                    body: "Summary of 5 documents from 2026-02-23",
                    deepLink: "/summaries/2026-02-23",
                    timestamp: "2026-02-23T06:00:00Z",
                    read: false
                ),
                PKMNotification(
                    notificationId: "notif-002",
                    notificationType: .weeklyReport,
                    title: "Weekly Report: 2026-W08",
                    body: "Report covering 15 documents for week 2026-W08",
                    deepLink: "/reports/2026-W08",
                    timestamp: "2026-02-22T20:00:00Z",
                    read: true
                ),
            ]
            return NotificationListResponse(notifications: notifications, count: notifications.count)
        }

        func markNotificationRead(id _: String) async throws {}

        // MARK: - Tasks

        func listTasks(status _: String, limit _: Int, cursor _: String?) async throws -> TaskListResponse {
            let fixtureTasks = [
                ExtractedTask(
                    taskId: "t-00000001",
                    description: "Review Q2 budget proposal",
                    status: "open",
                    source: "pattern",
                    marker: "checkbox",
                    documentPath: "notes/meeting-notes.md",
                    lineNumber: 15,
                    dueDate: "2026-03-20",
                    priority: "high"
                ),
                ExtractedTask(
                    taskId: "t-00000002",
                    description: "Update API documentation",
                    status: "open",
                    source: "pattern",
                    marker: "todo",
                    documentPath: "ideas/app-redesign.md",
                    lineNumber: 8
                ),
                ExtractedTask(
                    taskId: "t-00000003",
                    description: "Schedule follow-up with design team",
                    status: "completed",
                    source: "ai",
                    marker: "implicit",
                    documentPath: "notes/meeting-notes.md",
                    lineNumber: 22
                ),
            ]
            return TaskListResponse(tasks: fixtureTasks, count: fixtureTasks.count, nextCursor: nil)
        }

        func getTaskStats() async throws -> TaskStatsResponse {
            TaskStatsResponse(open: 5, completed: 12, total: 17)
        }

        // MARK: - Insight Viewed Status

        func markSummaryViewed(date _: String) async throws {}
        func markReportViewed(week _: String) async throws {}
        func markSearchSummaryViewed(monitorId _: String, timestamp _: String) async throws {}
        func markAllInsightsViewed() async throws {}
        func getUnviewedCount() async throws -> Int {
            1
        }
    }
#endif
