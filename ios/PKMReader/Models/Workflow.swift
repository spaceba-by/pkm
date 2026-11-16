import Foundation

/// What starts a custom agent workflow
enum WorkflowTriggerType: String, Codable, CaseIterable, Sendable {
    case document
    case schedule
    case manual
    case command

    var displayName: String {
        switch self {
        case .document: "Document"
        case .schedule: "Schedule"
        case .manual: "Manual"
        case .command: "@workflow Command"
        }
    }

    var icon: String {
        switch self {
        case .document: "doc.text"
        case .schedule: "clock"
        case .manual: "hand.tap"
        case .command: "at"
        }
    }

    var explanation: String {
        switch self {
        case .document: "Runs after a matching document is classified."
        case .schedule: "Runs on a recurring schedule over recent matching documents."
        case .manual: "Runs only when started from the app."
        case .command: "Runs when a note contains an @workflow:<name> line."
        }
    }
}

/// Recurrence for schedule-triggered workflows (UTC)
enum WorkflowScheduleFrequency: String, Codable, CaseIterable, Sendable {
    case hourly
    case daily
    case weekly

    var displayName: String {
        rawValue.capitalized
    }
}

/// Logical Bedrock model name
enum WorkflowModel: String, Codable, CaseIterable, Sendable {
    case haiku
    case sonnet

    var displayName: String {
        switch self {
        case .haiku: "Haiku (fast)"
        case .sonnet: "Sonnet (thorough)"
        }
    }
}

/// Where a workflow writes its result
enum WorkflowDestination: String, Codable, CaseIterable, Sendable {
    case s3
    case dynamodb
    case notification

    var displayName: String {
        switch self {
        case .s3: "Vault file (_agent/)"
        case .dynamodb: "Run record only"
        case .notification: "Push notification"
        }
    }

    var icon: String {
        switch self {
        case .s3: "doc.badge.plus"
        case .dynamodb: "tablecells"
        case .notification: "bell"
        }
    }
}

struct WorkflowSchedule: Codable, Hashable, Sendable {
    var frequency: WorkflowScheduleFrequency
    var minute: Int?
    var hour: Int?
    var dayOfWeek: String?

    var displayText: String {
        let time = String(format: "%02d:%02d UTC", hour ?? 0, minute ?? 0)
        switch frequency {
        case .hourly: return "Hourly at :\(String(format: "%02d", minute ?? 0))"
        case .daily: return "Daily at \(time)"
        case .weekly: return "Every \((dayOfWeek ?? "monday").capitalized) at \(time)"
        }
    }
}

struct WorkflowTrigger: Codable, Hashable, Sendable {
    var type: WorkflowTriggerType
    var schedule: WorkflowSchedule?
}

struct WorkflowFilter: Codable, Hashable, Sendable {
    var pathPrefix: String?
    var tags: [String]?
    var classifications: [String]?
    var lookbackDays: Int?

    var isEmpty: Bool {
        (pathPrefix ?? "").isEmpty && (tags ?? []).isEmpty && (classifications ?? []).isEmpty
    }

    var summary: String {
        var parts: [String] = []
        if let pathPrefix, !pathPrefix.isEmpty { parts.append("Path \(pathPrefix)") }
        if let classifications, !classifications.isEmpty {
            parts.append(classifications.map(\.capitalized).joined(separator: ", "))
        }
        if let tags, !tags.isEmpty { parts.append(tags.map { "#\($0)" }.joined(separator: " ")) }
        return parts.isEmpty ? "All documents" : parts.joined(separator: " · ")
    }
}

struct WorkflowPrompt: Codable, Hashable, Sendable {
    var system: String?
    var user: String
    var model: WorkflowModel
    var maxTokens: Int
    var temperature: Double
}

struct WorkflowOutput: Codable, Hashable, Sendable {
    var destination: WorkflowDestination
    var path: String?
}

/// A user-defined automation rule executed by Bedrock
struct Workflow: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let enabled: Bool
    let trigger: WorkflowTrigger
    let filter: WorkflowFilter
    let prompt: WorkflowPrompt
    let output: WorkflowOutput
    let cooldownMinutes: Int
    let runCount: Int
    let created: String?
    let updated: String?
    let nextRun: String?
    let lastRun: String?
    let lastStatus: String?
    let createdBy: String?
    let recentRuns: [WorkflowRun]?

    var triggerSummary: String {
        if trigger.type == .schedule, let schedule = trigger.schedule {
            return schedule.displayText
        }
        if trigger.type == .command {
            return "@workflow:\(name)"
        }
        return trigger.type.displayName
    }

    var lastStatusIcon: String {
        switch lastStatus {
        case "completed": "checkmark.circle"
        case "failed": "xmark.circle"
        case "running": "play.circle"
        default: "minus.circle"
        }
    }
}

/// One execution of a workflow
struct WorkflowRun: Identifiable, Codable, Hashable, Sendable {
    let runId: String
    let workflowId: String?
    let workflowName: String?
    let trigger: String?
    let status: String
    let started: String?
    let documentPath: String?
    let documentCount: Int?
    let completed: String?
    let durationMs: Int?
    let modelId: String?
    let inputTokens: Int?
    let outputTokens: Int?
    let outputS3Key: String?
    let result: String?
    let error: String?

    var id: String {
        runId
    }

    var isRunning: Bool {
        status == "running"
    }

    var isComplete: Bool {
        status == "completed"
    }

    var isFailed: Bool {
        status == "failed"
    }

    var statusIcon: String {
        switch status {
        case "running": "play.circle"
        case "completed": "checkmark.circle"
        case "failed": "xmark.circle"
        default: "questionmark.circle"
        }
    }

    var subjectText: String {
        if let documentPath { return documentPath }
        if let documentCount { return "\(documentCount) document\(documentCount == 1 ? "" : "s")" }
        return trigger?.capitalized ?? "Run"
    }

    var durationText: String? {
        guard let durationMs else { return nil }
        return durationMs < 1000 ? "\(durationMs) ms" : String(format: "%.1f s", Double(durationMs) / 1000)
    }
}

// MARK: - API Response Wrappers

/// Response from GET /workflows
struct WorkflowListResponse: Codable, Sendable {
    let workflows: [Workflow]
    let count: Int
}

/// Response from GET /workflows/{id}/runs
struct WorkflowRunListResponse: Codable, Sendable {
    let runs: [WorkflowRun]
    let count: Int
    let nextCursor: String?
}

/// Response from POST /workflows/{id}/run
struct WorkflowRunResponse: Codable, Sendable {
    let runId: String
    let workflowId: String
    let status: String
}

/// Request body for creating or updating a workflow. Absent fields are left unchanged on update.
struct WorkflowRequest: Codable, Sendable, Equatable {
    var name: String?
    var description: String?
    var enabled: Bool?
    var trigger: WorkflowTrigger?
    var filter: WorkflowFilter?
    var prompt: WorkflowPrompt?
    var output: WorkflowOutput?
    var cooldownMinutes: Int?
}

/// A template variable available in workflow prompts
struct WorkflowTemplateVariable: Identifiable, Hashable, Sendable {
    let name: String
    let scope: String
    let summary: String

    var id: String {
        name
    }

    var placeholder: String {
        "{{\(name)}}"
    }

    static let all: [WorkflowTemplateVariable] = [
        WorkflowTemplateVariable(
            name: "document.title",
            scope: "Document",
            summary: "Title of the triggering document"
        ),
        WorkflowTemplateVariable(name: "document.path", scope: "Document", summary: "Vault path of the document"),
        WorkflowTemplateVariable(name: "document.body", scope: "Document", summary: "Markdown without frontmatter"),
        WorkflowTemplateVariable(name: "document.content", scope: "Document", summary: "Full markdown as stored"),
        WorkflowTemplateVariable(name: "document.tags", scope: "Document", summary: "Comma-separated tags"),
        WorkflowTemplateVariable(name: "document.classification", scope: "Document", summary: "Classification"),
        WorkflowTemplateVariable(
            name: "document.frontmatter.<key>",
            scope: "Document",
            summary: "Any frontmatter field"
        ),
        WorkflowTemplateVariable(name: "entity.names", scope: "Entities", summary: "All extracted entities"),
        WorkflowTemplateVariable(name: "entity.people", scope: "Entities", summary: "People mentioned"),
        WorkflowTemplateVariable(name: "entity.organizations", scope: "Entities", summary: "Organizations mentioned"),
        WorkflowTemplateVariable(name: "entity.concepts", scope: "Entities", summary: "Concepts mentioned"),
        WorkflowTemplateVariable(name: "documents.count", scope: "Schedule", summary: "Number of selected documents"),
        WorkflowTemplateVariable(name: "documents.list", scope: "Schedule", summary: "One line per document"),
        WorkflowTemplateVariable(name: "documents.content", scope: "Schedule", summary: "Bodies of all documents"),
        WorkflowTemplateVariable(name: "command.args", scope: "Command", summary: "Text after @workflow:<name>"),
        WorkflowTemplateVariable(name: "workflow.name", scope: "Run", summary: "This workflow's name"),
        WorkflowTemplateVariable(name: "run.id", scope: "Run", summary: "Unique run identifier"),
        WorkflowTemplateVariable(name: "now.date", scope: "Run", summary: "Run date (UTC)"),
        WorkflowTemplateVariable(name: "now.weekday", scope: "Run", summary: "Run weekday (UTC)"),
    ]
}
