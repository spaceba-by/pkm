@testable import PKMReader

/// Shared builders for workflow tests
func makeWorkflow(id: String, name: String, enabled: Bool = true) -> Workflow {
    Workflow(
        id: id,
        name: name,
        description: "",
        enabled: enabled,
        trigger: WorkflowTrigger(type: .document, schedule: nil),
        filter: WorkflowFilter(pathPrefix: nil, tags: nil, classifications: nil, lookbackDays: nil),
        prompt: WorkflowPrompt(
            system: nil,
            user: "{{document.body}}",
            model: .haiku,
            maxTokens: 4096,
            temperature: 0.7
        ),
        output: WorkflowOutput(destination: .s3, path: nil),
        cooldownMinutes: 60,
        runCount: 0,
        created: nil,
        updated: nil,
        nextRun: nil,
        lastRun: nil,
        lastStatus: nil,
        createdBy: nil,
        recentRuns: nil
    )
}

func makeRun(id: String, status: String = "completed") -> WorkflowRun {
    WorkflowRun(
        runId: id,
        workflowId: "wf-1",
        workflowName: "alpha",
        trigger: "manual",
        status: status,
        started: "2026-01-01T00:00:00Z",
        documentPath: nil,
        documentCount: nil,
        completed: nil,
        durationMs: nil,
        modelId: nil,
        inputTokens: nil,
        outputTokens: nil,
        outputS3Key: nil,
        result: nil,
        error: nil
    )
}
