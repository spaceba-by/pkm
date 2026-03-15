import Foundation

/// A task extracted from a PKM document
struct ExtractedTask: Identifiable, Codable, Hashable, Sendable {
    /// Deterministic task ID (e.g. "t-12345678")
    let taskId: String

    /// Task description text
    let description: String

    /// Task status: "open" or "completed"
    let status: String

    /// Extraction source: "pattern" or "ai"
    let source: String

    /// Marker type: "checkbox", "todo", "action", "fixme", "implicit"
    let marker: String

    /// Source document S3 key
    let documentPath: String

    /// Line number in source document (optional)
    let lineNumber: Int?

    /// Due date in ISO format (optional)
    let dueDate: String?

    /// Priority: "high", "medium", "low" (optional)
    let priority: String?

    /// Surrounding context text (optional)
    let context: String?

    /// Last modified timestamp (optional)
    let modified: Date?

    var id: String { taskId }

    var isOpen: Bool { status == "open" }
    var isCompleted: Bool { status == "completed" }

    var displayMarker: String {
        switch marker {
        case "checkbox": "checkmark.square"
        case "todo": "list.bullet"
        case "action": "bolt"
        case "fixme": "wrench"
        case "implicit": "sparkles"
        default: "circle"
        }
    }

    var priorityColor: String? {
        switch priority {
        case "high": "red"
        case "medium": "orange"
        case "low": "blue"
        default: nil
        }
    }

    var documentName: String {
        let components = documentPath.split(separator: "/")
        let filename = components.last.map(String.init) ?? documentPath
        return filename.hasSuffix(".md") ? String(filename.dropLast(3)) : filename
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskId = try container.decode(String.self, forKey: .taskId)
        description = try container.decode(String.self, forKey: .description)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "open"
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "pattern"
        marker = try container.decodeIfPresent(String.self, forKey: .marker) ?? "checkbox"
        documentPath = try container.decodeIfPresent(String.self, forKey: .documentPath) ?? ""
        lineNumber = try container.decodeIfPresent(Int.self, forKey: .lineNumber)
        dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
        priority = try container.decodeIfPresent(String.self, forKey: .priority)
        context = try container.decodeIfPresent(String.self, forKey: .context)
        modified = try container.decodeIfPresent(Date.self, forKey: .modified)
    }

    init(
        taskId: String,
        description: String,
        status: String = "open",
        source: String = "pattern",
        marker: String = "checkbox",
        documentPath: String = "",
        lineNumber: Int? = nil,
        dueDate: String? = nil,
        priority: String? = nil,
        context: String? = nil,
        modified: Date? = nil
    ) {
        self.taskId = taskId
        self.description = description
        self.status = status
        self.source = source
        self.marker = marker
        self.documentPath = documentPath
        self.lineNumber = lineNumber
        self.dueDate = dueDate
        self.priority = priority
        self.context = context
        self.modified = modified
    }
}

/// Response from GET /tasks
struct TaskListResponse: Codable, Sendable {
    let tasks: [ExtractedTask]
    let count: Int
    let nextCursor: String?
}

/// Response from GET /tasks/stats
struct TaskStatsResponse: Codable, Sendable {
    let open: Int
    let completed: Int
    let total: Int
}
