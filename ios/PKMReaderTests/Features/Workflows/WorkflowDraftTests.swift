@testable import PKMReader
import XCTest

final class WorkflowDraftTests: XCTestCase {
    private func validDraft() -> WorkflowDraft {
        var draft = WorkflowDraft()
        draft.name = "action-items"
        draft.userPrompt = "Extract from {{document.body}}"
        return draft
    }

    // MARK: - Validation

    func test_defaultDraft_isInvalidWithoutNameAndPrompt() {
        let draft = WorkflowDraft()
        XCTAssertFalse(draft.isValid)
        XCTAssertEqual(draft.validationErrors.count, 2)
    }

    func test_validDraft_hasNoErrors() {
        XCTAssertTrue(validDraft().isValid)
    }

    func test_invalidName_isReported() {
        var draft = validDraft()
        draft.name = "Bad Name"
        XCTAssertTrue(draft.validationErrors.contains { $0.hasPrefix("Name must be") })
    }

    func test_unbalancedBraces_areReported() {
        var draft = validDraft()
        draft.userPrompt = "Hello {{document.title"
        XCTAssertTrue(draft.validationErrors.contains { $0.contains("unbalanced") })
    }

    func test_outputPathOutsideAgent_isReported() {
        var draft = validDraft()
        draft.outputPath = "notes/{{document.title}}.md"
        XCTAssertTrue(draft.validationErrors.contains { $0.contains("_agent/") })
        draft.outputPath = "_agent/actions/{{document.title}}.md"
        XCTAssertTrue(draft.isValid)
    }

    func test_maxTokensOutOfRange_isReported() {
        var draft = validDraft()
        draft.maxTokens = 50000
        XCTAssertTrue(draft.validationErrors.contains { $0.hasPrefix("Max tokens") })
    }

    // MARK: - Tags

    func test_tags_parsesCommaSeparatedAndStripsHash() {
        var draft = WorkflowDraft()
        draft.tagsText = " #work, q4 ,, project-x "
        XCTAssertEqual(draft.tags, ["work", "q4", "project-x"])
    }

    // MARK: - Request mapping

    func test_request_documentTrigger_omitsScheduleAndLookback() {
        var draft = validDraft()
        draft.pathPrefix = " meetings/ "
        draft.tagsText = "work"
        draft.classifications = [.meeting, .project]
        draft.systemPrompt = "  "
        let request = draft.request()

        XCTAssertEqual(request.name, "action-items")
        XCTAssertEqual(request.trigger?.type, .document)
        XCTAssertNil(request.trigger?.schedule)
        XCTAssertEqual(request.filter?.pathPrefix, "meetings/")
        XCTAssertEqual(request.filter?.tags, ["work"])
        XCTAssertEqual(request.filter?.classifications, ["meeting", "project"])
        XCTAssertNil(request.filter?.lookbackDays)
        XCTAssertNil(request.prompt?.system)
        XCTAssertNil(request.output?.path)
        XCTAssertEqual(request.cooldownMinutes, 60)
    }

    func test_request_weeklySchedule_includesScheduleAndLookback() {
        var draft = validDraft()
        draft.triggerType = .schedule
        draft.frequency = .weekly
        draft.hour = 9
        draft.minute = 30
        draft.dayOfWeek = "friday"
        draft.lookbackDays = 14
        let request = draft.request()

        XCTAssertEqual(
            request.trigger?.schedule,
            WorkflowSchedule(frequency: .weekly, minute: 30, hour: 9, dayOfWeek: "friday")
        )
        XCTAssertEqual(request.filter?.lookbackDays, 14)
    }

    func test_request_hourlySchedule_omitsHourAndDay() {
        var draft = validDraft()
        draft.triggerType = .schedule
        draft.frequency = .hourly
        draft.minute = 15
        let schedule = draft.request().trigger?.schedule

        XCTAssertEqual(schedule?.minute, 15)
        XCTAssertNil(schedule?.hour)
        XCTAssertNil(schedule?.dayOfWeek)
    }

    // MARK: - Round trip

    func test_initFromWorkflow_roundTripsThroughRequest() {
        let workflow = Workflow(
            id: "wf-1",
            name: "weekly-digest",
            description: "Digest",
            enabled: false,
            trigger: WorkflowTrigger(
                type: .schedule,
                schedule: WorkflowSchedule(frequency: .daily, minute: 0, hour: 7, dayOfWeek: nil)
            ),
            filter: WorkflowFilter(pathPrefix: "projects/", tags: ["x"], classifications: ["project"], lookbackDays: 3),
            prompt: WorkflowPrompt(
                system: "Sys",
                user: "User {{documents.list}}",
                model: .sonnet,
                maxTokens: 1024,
                temperature: 0.5
            ),
            output: WorkflowOutput(destination: .notification, path: nil),
            cooldownMinutes: 30,
            runCount: 0,
            created: nil,
            updated: nil,
            nextRun: nil,
            lastRun: nil,
            lastStatus: nil,
            createdBy: nil,
            recentRuns: nil
        )
        let request = WorkflowDraft(workflow: workflow).request()

        XCTAssertEqual(request.name, "weekly-digest")
        XCTAssertEqual(request.enabled, false)
        XCTAssertEqual(request.trigger, workflow.trigger)
        XCTAssertEqual(request.filter, workflow.filter)
        XCTAssertEqual(request.prompt, workflow.prompt)
        XCTAssertEqual(request.output, workflow.output)
        XCTAssertEqual(request.cooldownMinutes, 30)
    }
}
