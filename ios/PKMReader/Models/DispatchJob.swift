import Foundation

/// A dispatch job that runs a task on an ECS Fargate sandbox or local agent
struct DispatchJob: Identifiable, Codable, Hashable, Sendable {
    let jobId: String
    let status: String
    let agentType: String
    let taskDescription: String
    let contextPaths: [String]?
    let created: Date
    let updated: Date
    let startedAt: Date?
    let completedAt: Date?
    let error: String?
    let artifacts: [String]?
    let resultPath: String?
    let ecsTaskArn: String?
    let claimedBy: String?
    let createdBy: String?

    var id: String { jobId }

    var isActive: Bool { status == "pending" || status == "running" }
    var isComplete: Bool { status == "completed" }
    var isFailed: Bool { status == "failed" }

    var statusIcon: String {
        switch status {
        case "pending": "clock"
        case "running": "play.circle"
        case "completed": "checkmark.circle"
        case "failed": "xmark.circle"
        default: "questionmark.circle"
        }
    }

    var statusColor: String {
        switch status {
        case "pending": "orange"
        case "running": "blue"
        case "completed": "green"
        case "failed": "red"
        default: "gray"
        }
    }
}

/// Response for listing dispatch jobs
struct JobListResponse: Codable, Sendable {
    let jobs: [DispatchJob]
    let count: Int
    let nextCursor: String?
}

/// Response for getting a single job with result content
struct JobDetailResponse: Codable, Sendable {
    let job: DispatchJob
    let result: String?
}

/// Response for creating a dispatch job
struct CreateJobResponse: Codable, Sendable {
    let jobId: String
    let agentType: String
    let status: String
}

/// Agent type configuration
struct AgentType: Identifiable, Codable, Hashable, Sendable {
    let name: String
    let target: String
    let description: String
    let created: Date
    let updated: Date
    let ecsTaskDefinition: String?
    let ecsCluster: String?
    let ecsSubnets: [String]?
    let ecsSecurityGroups: [String]?
    let containerImage: String?
    let containerName: String?
    let cpu: Int?
    let memory: Int?

    var id: String { name }

    var isLocal: Bool { target == "local" }
    var isECS: Bool { target == "ecs" }

    var targetIcon: String {
        isLocal ? "desktopcomputer" : "cloud"
    }
}

/// Response for listing agent types
struct AgentTypeListResponse: Codable, Sendable {
    let agentTypes: [AgentType]
}
