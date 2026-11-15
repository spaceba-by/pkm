@testable import PKMReader
import XCTest

final class WorkflowTests: XCTestCase {
    private let decoder = JSONDecoder()

    // MARK: - Decoding

    func test_decode_fullWorkflowWithRecentRuns() throws {
        let json = """
        {
          "id": "wf-1", "name": "action-items", "description": "Extract tasks", "enabled": true,
          "trigger": {"type": "schedule",
                      "schedule": {"frequency": "weekly", "hour": 6, "minute": 30, "dayOfWeek": "monday"}},
          "filter": {"pathPrefix": "meetings/", "tags": ["work"], "classifications": ["meeting"], "lookbackDays": 7},
          "prompt": {"system": "Be brief", "user": "Summarize {{documents.content}}", "model": "sonnet",
                     "maxTokens": 2000, "temperature": 0.2},
          "output": {"destination": "s3", "path": "_agent/weekly/{{now.date}}.md"},
          "cooldownMinutes": 60, "runCount": 3, "created": "c", "updated": "u", "nextRun": "n",
          "lastRun": "l", "lastStatus": "completed", "createdBy": "user-1",
          "recentRuns": [{"runId": "r-1", "workflowId": "wf-1", "workflowName": "action-items", "trigger": "schedule",
                          "status": "completed", "started": "s", "documentCount": 4, "completed": "c",
                          "durationMs": 1500, "modelId": "m", "inputTokens": 10, "outputTokens": 20,
                          "outputS3Key": "_agent/weekly/x.md", "result": "ok"}]
        }
        """
        let workflow = try decoder.decode(Workflow.self, from: Data(json.utf8))

        XCTAssertEqual(workflow.id, "wf-1")
        XCTAssertEqual(workflow.trigger.type, .schedule)
        XCTAssertEqual(workflow.trigger.schedule?.frequency, .weekly)
        XCTAssertEqual(workflow.trigger.schedule?.dayOfWeek, "monday")
        XCTAssertEqual(workflow.filter.classifications, ["meeting"])
        XCTAssertEqual(workflow.prompt.model, .sonnet)
        XCTAssertEqual(workflow.output.destination, .s3)
        XCTAssertEqual(workflow.runCount, 3)
        XCTAssertEqual(workflow.recentRuns?.count, 1)
        XCTAssertEqual(workflow.recentRuns?.first?.durationText, "1.5 s")
        XCTAssertEqual(workflow.recentRuns?.first?.subjectText, "4 documents")
        XCTAssertEqual(workflow.triggerSummary, "Every Monday at 06:30 UTC")
    }

    func test_decode_minimalWorkflow() throws {
        let json = """
        {"id": "wf-2", "name": "digest", "description": "", "enabled": false,
         "trigger": {"type": "command"}, "filter": {},
         "prompt": {"user": "Do {{command.args}}", "model": "haiku", "maxTokens": 4096, "temperature": 0.7},
         "output": {"destination": "notification"}, "cooldownMinutes": 60, "runCount": 0}
        """
        let workflow = try decoder.decode(Workflow.self, from: Data(json.utf8))

        XCTAssertEqual(workflow.triggerSummary, "@workflow:digest")
        XCTAssertTrue(workflow.filter.isEmpty)
        XCTAssertEqual(workflow.filter.summary, "All documents")
        XCTAssertNil(workflow.recentRuns)
        XCTAssertEqual(workflow.lastStatusIcon, "minus.circle")
    }

    func test_decode_runListResponse() throws {
        let json = """
        {"runs": [{"runId": "r-1", "status": "failed", "error": "boom", "documentPath": "a.md", "durationMs": 300}],
         "count": 1, "nextCursor": "abc"}
        """
        let response = try decoder.decode(WorkflowRunListResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.nextCursor, "abc")
        XCTAssertEqual(response.runs.first?.id, "r-1")
        XCTAssertTrue(response.runs.first?.isFailed ?? false)
        XCTAssertEqual(response.runs.first?.subjectText, "a.md")
        XCTAssertEqual(response.runs.first?.durationText, "300 ms")
    }

    // MARK: - Request encoding

    func test_encode_request_omitsAbsentFields() throws {
        let request = WorkflowRequest(enabled: false)
        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object.count, 1)
        XCTAssertEqual(object["enabled"] as? Bool, false)
    }

    // MARK: - Filter summary

    func test_filterSummary_joinsConditions() {
        let filter = WorkflowFilter(
            pathPrefix: "meetings/",
            tags: ["work", "q4"],
            classifications: ["meeting"],
            lookbackDays: nil
        )
        XCTAssertEqual(filter.summary, "Path meetings/ · Meeting · #work #q4")
    }

    // MARK: - Schedule text

    func test_scheduleDisplayText() {
        XCTAssertEqual(
            WorkflowSchedule(frequency: .hourly, minute: 15, hour: nil, dayOfWeek: nil).displayText,
            "Hourly at :15"
        )
        XCTAssertEqual(
            WorkflowSchedule(frequency: .daily, minute: 0, hour: 6, dayOfWeek: nil).displayText,
            "Daily at 06:00 UTC"
        )
    }
}
