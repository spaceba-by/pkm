@testable import PKMReader
import XCTest

final class ExtractedTaskTests: XCTestCase {
    // MARK: - Identity

    func test_id_returnsTaskId() {
        let task = makeTask(id: "t-12345678")
        XCTAssertEqual(task.id, "t-12345678")
    }

    // MARK: - Status

    func test_isOpen_trueForOpen() {
        XCTAssertTrue(makeTask(status: "open").isOpen)
    }

    func test_isOpen_falseForCompleted() {
        XCTAssertFalse(makeTask(status: "completed").isOpen)
    }

    func test_isCompleted_trueForCompleted() {
        XCTAssertTrue(makeTask(status: "completed").isCompleted)
    }

    func test_isCompleted_falseForOpen() {
        XCTAssertFalse(makeTask(status: "open").isCompleted)
    }

    // MARK: - Display Marker

    func test_displayMarker_checkbox() {
        XCTAssertEqual(makeTask(marker: "checkbox").displayMarker, "checkmark.square")
    }

    func test_displayMarker_todo() {
        XCTAssertEqual(makeTask(marker: "todo").displayMarker, "list.bullet")
    }

    func test_displayMarker_action() {
        XCTAssertEqual(makeTask(marker: "action").displayMarker, "bolt")
    }

    func test_displayMarker_fixme() {
        XCTAssertEqual(makeTask(marker: "fixme").displayMarker, "wrench")
    }

    func test_displayMarker_implicit() {
        XCTAssertEqual(makeTask(marker: "implicit").displayMarker, "sparkles")
    }

    func test_displayMarker_unknown() {
        XCTAssertEqual(makeTask(marker: "other").displayMarker, "circle")
    }

    // MARK: - Priority Color

    func test_priorityColor_high() {
        XCTAssertEqual(makeTask(priority: "high").priorityColor, "red")
    }

    func test_priorityColor_medium() {
        XCTAssertEqual(makeTask(priority: "medium").priorityColor, "orange")
    }

    func test_priorityColor_low() {
        XCTAssertEqual(makeTask(priority: "low").priorityColor, "blue")
    }

    func test_priorityColor_nil_whenNoPriority() {
        XCTAssertNil(makeTask(priority: nil).priorityColor)
    }

    func test_priorityColor_nil_forUnknown() {
        XCTAssertNil(makeTask(priority: "unknown").priorityColor)
    }

    // MARK: - Document Name

    func test_documentName_stripsDirectoryAndExtension() {
        let task = makeTask(documentPath: "meetings/2025-03/standup.md")
        XCTAssertEqual(task.documentName, "standup")
    }

    func test_documentName_handlesNoDirectory() {
        let task = makeTask(documentPath: "notes.md")
        XCTAssertEqual(task.documentName, "notes")
    }

    func test_documentName_preservesNonMdExtension() {
        let task = makeTask(documentPath: "folder/file.txt")
        XCTAssertEqual(task.documentName, "file.txt")
    }

    func test_documentName_handlesEmptyPath() {
        let task = makeTask(documentPath: "")
        XCTAssertEqual(task.documentName, "")
    }

    func test_documentName_handlesDeepNesting() {
        let task = makeTask(documentPath: "a/b/c/d/deep.md")
        XCTAssertEqual(task.documentName, "deep")
    }

    // MARK: - Codable Defaults

    func test_decode_withMinimalFields() throws {
        let json = Data("""
        {"taskId": "t-1", "description": "Do something"}
        """.utf8)
        let decoder = JSONDecoder()
        let task = try decoder.decode(ExtractedTask.self, from: json)
        XCTAssertEqual(task.taskId, "t-1")
        XCTAssertEqual(task.description, "Do something")
        XCTAssertEqual(task.status, "open")
        XCTAssertEqual(task.source, "pattern")
        XCTAssertEqual(task.marker, "checkbox")
        XCTAssertEqual(task.documentPath, "")
        XCTAssertNil(task.lineNumber)
        XCTAssertNil(task.dueDate)
        XCTAssertNil(task.priority)
    }

    func test_decode_withAllFields() throws {
        let json = Data("""
        {
            "taskId": "t-2",
            "description": "Fix bug",
            "status": "completed",
            "source": "ai",
            "marker": "fixme",
            "documentPath": "bugs/issue.md",
            "lineNumber": 42,
            "dueDate": "2026-04-01",
            "priority": "high",
            "context": "Found in review"
        }
        """.utf8)
        let task = try JSONDecoder().decode(ExtractedTask.self, from: json)
        XCTAssertEqual(task.status, "completed")
        XCTAssertEqual(task.source, "ai")
        XCTAssertEqual(task.marker, "fixme")
        XCTAssertEqual(task.documentPath, "bugs/issue.md")
        XCTAssertEqual(task.lineNumber, 42)
        XCTAssertEqual(task.dueDate, "2026-04-01")
        XCTAssertEqual(task.priority, "high")
        XCTAssertEqual(task.context, "Found in review")
    }

    // MARK: - Helpers

    private func makeTask(
        id: String = "t-1",
        status: String = "open",
        marker: String = "checkbox",
        priority: String? = nil,
        documentPath: String = "docs/test.md"
    ) -> ExtractedTask {
        ExtractedTask(
            taskId: id,
            description: "Test task",
            status: status,
            marker: marker,
            documentPath: documentPath,
            priority: priority
        )
    }
}
