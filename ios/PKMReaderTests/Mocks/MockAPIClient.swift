import Foundation
@testable import PKMReader

/// Mock API client for unit testing
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    // MARK: - Configurable Results

    var listDocumentsResult: Result<DocumentListResponse, Error> = .success(
        DocumentListResponse(documents: [], nextCursor: nil)
    )
    var getDocumentResult: Result<Document, Error>?
    var searchResult: Result<[Document], Error> = .success([])
    var listTagsResult: Result<[Tag], Error> = .success([])
    var listClassificationsResult: Result<[ClassificationCount], Error> = .success([])
    var listSummariesResult: Result<[Summary], Error> = .success([])
    var listReportsResult: Result<[Report], Error> = .success([])
    var documentsByTagResult: Result<[Document], Error> = .success([])
    var updateClassificationResult: Result<Void, Error> = .success(())
    var createDocumentResult: Result<CreateDocumentResponse, Error> = .success(
        CreateDocumentResponse(key: "test.md", title: "Test", createdAt: "2024-01-01T00:00:00Z")
    )
    var updateDocumentResult: Result<Void, Error> = .success(())
    var deleteDocumentResult: Result<Void, Error> = .success(())
    var getGraphDataResult: Result<GraphDataResponse, Error> = .success(
        GraphDataResponse(nodes: [], edges: [], nodeCount: 0, edgeCount: 0)
    )
    var listSearchMonitorsResult: Result<[SearchMonitor], Error> = .success([])
    var getSearchMonitorResult: Result<SearchMonitorDetailResponse, Error>?
    var createSearchMonitorResult: Result<SearchMonitor, Error>?
    var updateSearchMonitorResult: Result<SearchMonitor, Error>?
    var deleteSearchMonitorResult: Result<Void, Error> = .success(())
    var listSearchMonitorSummariesResult: Result<[SearchSummary], Error> = .success([])
    var getSearchMonitorSummaryResult: Result<SearchSummary, Error>?

    // MARK: - Call Tracking

    private(set) var listDocumentsCallCount = 0
    private(set) var lastListDocumentsClassification: DocumentClassification?
    private(set) var lastListDocumentsLimit: Int?
    private(set) var lastListDocumentsCursor: String?
    private(set) var lastListDocumentsSort: DocumentSortOrder?
    private(set) var getDocumentCallCount = 0
    private(set) var lastGetDocumentKey: String?
    private(set) var searchCallCount = 0
    private(set) var lastSearchQuery: String?
    private(set) var lastSearchLimit: Int?
    private(set) var lastSearchMode: SearchMode?
    private(set) var listTagsCallCount = 0
    private(set) var documentsByTagCallCount = 0
    private(set) var lastDocumentsByTagTag: String?
    private(set) var lastDocumentsByTagLimit: Int?
    private(set) var updateClassificationCallCount = 0
    private(set) var lastUpdateClassificationDocumentId: String?
    private(set) var lastUpdateClassificationValue: DocumentClassification?
    private(set) var createDocumentCallCount = 0
    private(set) var updateDocumentCallCount = 0
    private(set) var deleteDocumentCallCount = 0
    private(set) var getGraphDataCallCount = 0
    private(set) var listSearchMonitorsCallCount = 0
    private(set) var getSearchMonitorCallCount = 0
    private(set) var lastGetSearchMonitorId: String?
    private(set) var createSearchMonitorCallCount = 0
    private(set) var lastCreateSearchMonitorRequest: SearchMonitorRequest?
    private(set) var updateSearchMonitorCallCount = 0
    private(set) var lastUpdateSearchMonitorId: String?
    private(set) var lastUpdateSearchMonitorRequest: SearchMonitorRequest?
    private(set) var deleteSearchMonitorCallCount = 0
    private(set) var lastDeleteSearchMonitorId: String?
    private(set) var listSearchMonitorSummariesCallCount = 0
    private(set) var lastListSearchMonitorSummariesMonitorId: String?
    private(set) var lastListSearchMonitorSummariesLimit: Int?
    private(set) var getSearchMonitorSummaryCallCount = 0
    private(set) var lastGetSearchMonitorSummaryMonitorId: String?
    private(set) var lastGetSearchMonitorSummaryTimestamp: String?

    // MARK: - APIClientProtocol

    func listDocuments(
        classification: DocumentClassification?,
        limit: Int,
        cursor: String?,
        sort: DocumentSortOrder? = nil
    ) async throws -> DocumentListResponse {
        listDocumentsCallCount += 1
        lastListDocumentsClassification = classification
        lastListDocumentsLimit = limit
        lastListDocumentsCursor = cursor
        lastListDocumentsSort = sort
        return try listDocumentsResult.get()
    }

    func getDocument(key: String) async throws -> Document {
        getDocumentCallCount += 1
        lastGetDocumentKey = key
        if let result = getDocumentResult {
            return try result.get()
        }
        throw APIError.invalidResponse
    }

    func search(query: String, limit: Int, mode: SearchMode = .keyword) async throws -> [Document] {
        searchCallCount += 1
        lastSearchQuery = query
        lastSearchLimit = limit
        lastSearchMode = mode
        return try searchResult.get()
    }

    func listTags() async throws -> [Tag] {
        listTagsCallCount += 1
        return try listTagsResult.get()
    }

    func listClassifications() async throws -> [ClassificationCount] {
        try listClassificationsResult.get()
    }

    func listSummaries(limit _: Int) async throws -> [Summary] {
        try listSummariesResult.get()
    }

    func listReports(limit _: Int) async throws -> [Report] {
        try listReportsResult.get()
    }

    func documentsByTag(tag: String, limit: Int) async throws -> [Document] {
        documentsByTagCallCount += 1
        lastDocumentsByTagTag = tag
        lastDocumentsByTagLimit = limit
        return try documentsByTagResult.get()
    }

    func updateClassification(
        documentId: String,
        classification: DocumentClassification
    ) async throws {
        updateClassificationCallCount += 1
        lastUpdateClassificationDocumentId = documentId
        lastUpdateClassificationValue = classification
        try updateClassificationResult.get()
    }

    func createDocument(key _: String, title _: String?, content _: String) async throws -> CreateDocumentResponse {
        createDocumentCallCount += 1
        return try createDocumentResult.get()
    }

    func updateDocument(key _: String, content _: String, ifUnmodifiedSince _: String?) async throws {
        updateDocumentCallCount += 1
        try updateDocumentResult.get()
    }

    func deleteDocument(key _: String) async throws {
        deleteDocumentCallCount += 1
        try deleteDocumentResult.get()
    }

    func getGraphData() async throws -> GraphDataResponse {
        getGraphDataCallCount += 1
        return try getGraphDataResult.get()
    }

    // MARK: - Search Monitors

    func listSearchMonitors() async throws -> [SearchMonitor] {
        listSearchMonitorsCallCount += 1
        return try listSearchMonitorsResult.get()
    }

    func getSearchMonitor(id: String) async throws -> SearchMonitorDetailResponse {
        getSearchMonitorCallCount += 1
        lastGetSearchMonitorId = id
        if let result = getSearchMonitorResult {
            return try result.get()
        }
        throw APIError.invalidResponse
    }

    func createSearchMonitor(request: SearchMonitorRequest) async throws -> SearchMonitor {
        createSearchMonitorCallCount += 1
        lastCreateSearchMonitorRequest = request
        if let result = createSearchMonitorResult {
            return try result.get()
        }
        throw APIError.invalidResponse
    }

    func updateSearchMonitor(id: String, request: SearchMonitorRequest) async throws -> SearchMonitor {
        updateSearchMonitorCallCount += 1
        lastUpdateSearchMonitorId = id
        lastUpdateSearchMonitorRequest = request
        if let result = updateSearchMonitorResult {
            return try result.get()
        }
        throw APIError.invalidResponse
    }

    func deleteSearchMonitor(id: String) async throws {
        deleteSearchMonitorCallCount += 1
        lastDeleteSearchMonitorId = id
        try deleteSearchMonitorResult.get()
    }

    func listSearchMonitorSummaries(monitorId: String, limit: Int) async throws -> [SearchSummary] {
        listSearchMonitorSummariesCallCount += 1
        lastListSearchMonitorSummariesMonitorId = monitorId
        lastListSearchMonitorSummariesLimit = limit
        return try listSearchMonitorSummariesResult.get()
    }

    func getSearchMonitorSummary(monitorId: String, timestamp: String) async throws -> SearchSummary {
        getSearchMonitorSummaryCallCount += 1
        lastGetSearchMonitorSummaryMonitorId = monitorId
        lastGetSearchMonitorSummaryTimestamp = timestamp
        if let result = getSearchMonitorSummaryResult {
            return try result.get()
        }
        throw APIError.invalidResponse
    }

    // MARK: - Chat

    var sendChatMessageResult: Result<ChatSendResponse, Error> = .success(
        ChatSendResponse(
            conversationId: "test-conv-id",
            userMessage: ChatMessage(
                id: "test-msg-id",
                role: .user,
                content: "test message",
                timestamp: "2026-03-14T00:00:00Z",
                status: .complete
            ),
            assistantMessageId: "test-assistant-msg-id"
        )
    )
    private(set) var sendChatMessageCallCount = 0
    private(set) var lastSendChatMessage: String?
    private(set) var lastSendChatConversationId: String?

    var listConversationsResult: Result<[ChatConversation], Error> = .success([])
    private(set) var listConversationsCallCount = 0

    var getConversationMessagesResult: Result<[ChatMessage], Error> = .success([])
    private(set) var getConversationMessagesCallCount = 0
    private(set) var lastGetConversationMessagesId: String?

    func sendChatMessage(message: String, conversationId: String?) async throws -> ChatSendResponse {
        sendChatMessageCallCount += 1
        lastSendChatMessage = message
        lastSendChatConversationId = conversationId
        return try sendChatMessageResult.get()
    }

    func listConversations() async throws -> [ChatConversation] {
        listConversationsCallCount += 1
        return try listConversationsResult.get()
    }

    func getConversationMessages(conversationId: String) async throws -> [ChatMessage] {
        getConversationMessagesCallCount += 1
        lastGetConversationMessagesId = conversationId
        return try getConversationMessagesResult.get()
    }

    // MARK: - Device Tokens & Notifications

    var registerDeviceResult: Result<DeviceRegistrationResponse, Error> = .success(
        DeviceRegistrationResponse(deviceId: "mock-device", registered: true)
    )
    private(set) var registerDeviceCallCount = 0
    var unregisterDeviceResult: Result<Void, Error> = .success(())
    private(set) var unregisterDeviceCallCount = 0
    var listNotificationsResult: Result<NotificationListResponse, Error> = .success(
        NotificationListResponse(notifications: [], count: 0)
    )
    private(set) var listNotificationsCallCount = 0
    var markNotificationReadResult: Result<Void, Error> = .success(())
    private(set) var markNotificationReadCallCount = 0
    private(set) var lastMarkNotificationReadId: String?

    func registerDevice(request _: DeviceRegistrationRequest) async throws -> DeviceRegistrationResponse {
        registerDeviceCallCount += 1
        return try registerDeviceResult.get()
    }

    func unregisterDevice(deviceId _: String) async throws {
        unregisterDeviceCallCount += 1
        try unregisterDeviceResult.get()
    }

    func listNotifications() async throws -> NotificationListResponse {
        listNotificationsCallCount += 1
        return try listNotificationsResult.get()
    }

    func markNotificationRead(id: String) async throws {
        markNotificationReadCallCount += 1
        lastMarkNotificationReadId = id
        try markNotificationReadResult.get()
    }

    // MARK: - Tasks

    var listTasksResult: Result<TaskListResponse, Error> = .success(
        TaskListResponse(tasks: [], count: 0, nextCursor: nil)
    )
    private(set) var listTasksCallCount = 0
    private(set) var lastListTasksStatus: String?
    var getTaskStatsResult: Result<TaskStatsResponse, Error> = .success(
        TaskStatsResponse(open: 0, completed: 0, total: 0)
    )
    private(set) var getTaskStatsCallCount = 0

    func listTasks(status: String, limit _: Int, cursor _: String?) async throws -> TaskListResponse {
        listTasksCallCount += 1
        lastListTasksStatus = status
        return try listTasksResult.get()
    }

    func getTaskStats() async throws -> TaskStatsResponse {
        getTaskStatsCallCount += 1
        return try getTaskStatsResult.get()
    }

    // MARK: - Dispatch Jobs

    var listJobsResult: Result<JobListResponse, Error> = .success(
        JobListResponse(jobs: [], count: 0, nextCursor: nil)
    )
    private(set) var listJobsCallCount = 0
    private(set) var lastListJobsStatus: String?

    var getJobResult: Result<JobDetailResponse, Error>?
    private(set) var getJobCallCount = 0
    private(set) var lastGetJobId: String?

    var createJobResult: Result<CreateJobResponse, Error> = .success(
        CreateJobResponse(jobId: "test-job-id", agentType: "test-type", status: "accepted")
    )
    private(set) var createJobCallCount = 0
    private(set) var lastCreateJobDescription: String?
    private(set) var lastCreateJobAgentType: String?

    var listAgentTypesResult: Result<[AgentType], Error> = .success([])
    private(set) var listAgentTypesCallCount = 0

    func listJobs(status: String?, limit _: Int, cursor _: String?) async throws -> JobListResponse {
        listJobsCallCount += 1
        lastListJobsStatus = status
        return try listJobsResult.get()
    }

    func getJob(jobId: String) async throws -> JobDetailResponse {
        getJobCallCount += 1
        lastGetJobId = jobId
        if let result = getJobResult {
            return try result.get()
        }
        throw APIError.invalidResponse
    }

    func createJob(taskDescription: String, contextPaths _: [String]?, agentType: String) async throws -> CreateJobResponse {
        createJobCallCount += 1
        lastCreateJobDescription = taskDescription
        lastCreateJobAgentType = agentType
        return try createJobResult.get()
    }

    func listAgentTypes() async throws -> [AgentType] {
        listAgentTypesCallCount += 1
        return try listAgentTypesResult.get()
    }

    // MARK: - Insight Viewed Status

    var markSummaryViewedResult: Result<Void, Error> = .success(())
    private(set) var markSummaryViewedCallCount = 0
    private(set) var lastMarkSummaryViewedDate: String?
    var markReportViewedResult: Result<Void, Error> = .success(())
    private(set) var markReportViewedCallCount = 0
    private(set) var lastMarkReportViewedWeek: String?
    var markSearchSummaryViewedResult: Result<Void, Error> = .success(())
    private(set) var markSearchSummaryViewedCallCount = 0
    private(set) var lastMarkSearchSummaryViewedMonitorId: String?
    private(set) var lastMarkSearchSummaryViewedTimestamp: String?
    var markAllInsightsViewedResult: Result<Void, Error> = .success(())
    private(set) var markAllInsightsViewedCallCount = 0
    var getUnviewedCountResult: Result<Int, Error> = .success(0)
    private(set) var getUnviewedCountCallCount = 0

    func markSummaryViewed(date: String) async throws {
        markSummaryViewedCallCount += 1
        lastMarkSummaryViewedDate = date
        try markSummaryViewedResult.get()
    }

    func markReportViewed(week: String) async throws {
        markReportViewedCallCount += 1
        lastMarkReportViewedWeek = week
        try markReportViewedResult.get()
    }

    func markSearchSummaryViewed(monitorId: String, timestamp: String) async throws {
        markSearchSummaryViewedCallCount += 1
        lastMarkSearchSummaryViewedMonitorId = monitorId
        lastMarkSearchSummaryViewedTimestamp = timestamp
        try markSearchSummaryViewedResult.get()
    }

    func markAllInsightsViewed() async throws {
        markAllInsightsViewedCallCount += 1
        try markAllInsightsViewedResult.get()
    }

    func getUnviewedCount() async throws -> Int {
        getUnviewedCountCallCount += 1
        return try getUnviewedCountResult.get()
    }

    // MARK: - Test Helpers

    // swiftlint:disable function_body_length
    func reset() {
        listDocumentsCallCount = 0
        lastListDocumentsClassification = nil
        lastListDocumentsLimit = nil
        lastListDocumentsCursor = nil
        lastListDocumentsSort = nil
        getDocumentCallCount = 0
        lastGetDocumentKey = nil
        searchCallCount = 0
        lastSearchQuery = nil
        lastSearchLimit = nil
        lastSearchMode = nil
        listTagsCallCount = 0
        documentsByTagCallCount = 0
        lastDocumentsByTagTag = nil
        lastDocumentsByTagLimit = nil
        updateClassificationCallCount = 0
        lastUpdateClassificationDocumentId = nil
        lastUpdateClassificationValue = nil
        createDocumentCallCount = 0
        updateDocumentCallCount = 0
        deleteDocumentCallCount = 0
        getGraphDataCallCount = 0
        listSearchMonitorsCallCount = 0
        getSearchMonitorCallCount = 0
        lastGetSearchMonitorId = nil
        createSearchMonitorCallCount = 0
        lastCreateSearchMonitorRequest = nil
        updateSearchMonitorCallCount = 0
        lastUpdateSearchMonitorId = nil
        lastUpdateSearchMonitorRequest = nil
        deleteSearchMonitorCallCount = 0
        lastDeleteSearchMonitorId = nil
        listSearchMonitorSummariesCallCount = 0
        lastListSearchMonitorSummariesMonitorId = nil
        lastListSearchMonitorSummariesLimit = nil
        getSearchMonitorSummaryCallCount = 0
        lastGetSearchMonitorSummaryMonitorId = nil
        lastGetSearchMonitorSummaryTimestamp = nil
        sendChatMessageCallCount = 0
        lastSendChatMessage = nil
        lastSendChatConversationId = nil
        listConversationsCallCount = 0
        getConversationMessagesCallCount = 0
        lastGetConversationMessagesId = nil
        registerDeviceCallCount = 0
        unregisterDeviceCallCount = 0
        listNotificationsCallCount = 0
        markNotificationReadCallCount = 0
        lastMarkNotificationReadId = nil
        listTasksCallCount = 0
        lastListTasksStatus = nil
        getTaskStatsCallCount = 0
        markSummaryViewedCallCount = 0
        lastMarkSummaryViewedDate = nil
        markReportViewedCallCount = 0
        lastMarkReportViewedWeek = nil
        markSearchSummaryViewedCallCount = 0
        lastMarkSearchSummaryViewedMonitorId = nil
        lastMarkSearchSummaryViewedTimestamp = nil
        markAllInsightsViewedCallCount = 0
        getUnviewedCountCallCount = 0
        listJobsCallCount = 0
        lastListJobsStatus = nil
        getJobCallCount = 0
        lastGetJobId = nil
        createJobCallCount = 0
        lastCreateJobDescription = nil
        lastCreateJobAgentType = nil
        listAgentTypesCallCount = 0
    }
    // swiftlint:enable function_body_length
}
