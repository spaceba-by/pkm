import Foundation

/// Editable form state for a workflow, with client-side validation mirroring the API
struct WorkflowDraft: Equatable, Sendable {
    static let daysOfWeek = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    static let maxTokensRange = 1 ... 16000
    static let cooldownRange = 0 ... 10080
    static let lookbackRange = 1 ... 90
    static let outputRoot = "_agent/"

    var name = ""
    var description = ""
    var enabled = true

    var triggerType: WorkflowTriggerType = .document
    var frequency: WorkflowScheduleFrequency = .daily
    var hour = 6
    var minute = 0
    var dayOfWeek = "monday"

    var pathPrefix = ""
    var tagsText = ""
    var classifications: Set<DocumentClassification> = []
    var lookbackDays = 7

    var systemPrompt = ""
    var userPrompt = ""
    var model: WorkflowModel = .haiku
    var maxTokens = 4096
    var temperature = 0.7

    var destination: WorkflowDestination = .s3
    var outputPath = ""
    var cooldownMinutes = 60

    init() {}

    init(workflow: Workflow) {
        name = workflow.name
        description = workflow.description
        enabled = workflow.enabled
        triggerType = workflow.trigger.type
        if let schedule = workflow.trigger.schedule {
            frequency = schedule.frequency
            hour = schedule.hour ?? 0
            minute = schedule.minute ?? 0
            dayOfWeek = schedule.dayOfWeek?.lowercased() ?? "monday"
        }
        pathPrefix = workflow.filter.pathPrefix ?? ""
        tagsText = (workflow.filter.tags ?? []).joined(separator: ", ")
        classifications = Set((workflow.filter.classifications ?? [])
            .compactMap(DocumentClassification.init(rawValue:)))
        lookbackDays = workflow.filter.lookbackDays ?? 7
        systemPrompt = workflow.prompt.system ?? ""
        userPrompt = workflow.prompt.user
        model = workflow.prompt.model
        maxTokens = workflow.prompt.maxTokens
        temperature = workflow.prompt.temperature
        destination = workflow.output.destination
        outputPath = workflow.output.path ?? ""
        cooldownMinutes = workflow.cooldownMinutes
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var tags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
            .filter { !$0.isEmpty }
    }

    var usesDocumentSet: Bool {
        triggerType == .schedule
    }

    var validationErrors: [String] {
        var errors: [String] = []
        if trimmedName.range(of: "^[a-z0-9][a-z0-9-]{1,63}$", options: .regularExpression) == nil {
            errors.append("Name must be 2-64 lower-case letters, digits or hyphens")
        }
        if userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Prompt is required")
        }
        for (label, text) in [("Prompt", userPrompt), ("System prompt", systemPrompt), ("Output path", outputPath)]
            where !Self.bracesBalanced(text) {
            errors.append("\(label) has unbalanced {{ }}")
        }
        if !outputPath.isEmpty, !outputPath.trimmingCharacters(in: .whitespaces).hasPrefix(Self.outputRoot) {
            errors.append("Output path must start with \(Self.outputRoot)")
        }
        if !Self.maxTokensRange.contains(maxTokens) {
            errors
                .append(
                    "Max tokens must be between \(Self.maxTokensRange.lowerBound) and \(Self.maxTokensRange.upperBound)"
                )
        }
        return errors
    }

    var isValid: Bool {
        validationErrors.isEmpty
    }

    func request() -> WorkflowRequest {
        let schedule: WorkflowSchedule? = triggerType == .schedule
            ? WorkflowSchedule(
                frequency: frequency,
                minute: minute,
                hour: frequency == .hourly ? nil : hour,
                dayOfWeek: frequency == .weekly ? dayOfWeek : nil
            )
            : nil
        let trimmedPrefix = pathPrefix.trimmingCharacters(in: .whitespaces)
        let trimmedSystem = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOutputPath = outputPath.trimmingCharacters(in: .whitespaces)
        return WorkflowRequest(
            name: trimmedName,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            enabled: enabled,
            trigger: WorkflowTrigger(type: triggerType, schedule: schedule),
            filter: WorkflowFilter(
                pathPrefix: trimmedPrefix.isEmpty ? nil : trimmedPrefix,
                tags: tags.isEmpty ? nil : tags,
                classifications: classifications.isEmpty
                    ? nil
                    : classifications.map(\.rawValue).sorted(),
                lookbackDays: usesDocumentSet ? lookbackDays : nil
            ),
            prompt: WorkflowPrompt(
                system: trimmedSystem.isEmpty ? nil : trimmedSystem,
                user: userPrompt,
                model: model,
                maxTokens: maxTokens,
                temperature: temperature
            ),
            output: WorkflowOutput(
                destination: destination,
                path: trimmedOutputPath.isEmpty ? nil : trimmedOutputPath
            ),
            cooldownMinutes: cooldownMinutes
        )
    }

    static func bracesBalanced(_ text: String) -> Bool {
        text.components(separatedBy: "{{").count == text.components(separatedBy: "}}").count
    }
}
