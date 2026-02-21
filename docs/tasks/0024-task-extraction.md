# Task 0024: Automated Task Extraction

**Status**: Planned

## Specifications

Automatically detect and extract TODOs, action items, and tasks from processed documents. Many PKM notes contain actionable items in various formats — markdown checkboxes (`- [ ]`), inline mentions ("TODO: review proposal"), meeting action items, and deadline references. This task adds an extraction pipeline that identifies these items, structures them, and makes them queryable via API and the iOS app.

### Extraction Approach

A new `extract_tasks` Lambda runs as part of the document processing pipeline (after extract_metadata). It uses a combination of regex pattern matching for common formats and Bedrock AI for natural language task detection. Extracted tasks reference their source document and include metadata like due dates, assignees, and completion status.

### Task Data Model

```
task_id: UUID
source_document: String (S3 key)
description: String
status: "open" | "completed" | "cancelled"
due_date: String? (ISO-8601)
assignee: String?
priority: "high" | "medium" | "low" | nil
context: String (surrounding text from source)
extracted_at: ISO-8601
line_number: Int?
```

### Key Capabilities

- Pattern-based extraction: markdown checkboxes, "TODO:", "ACTION:", "FIXME:" markers
- AI-assisted extraction: Bedrock identifies implicit tasks in meeting notes and prose
- Source document linking: each task references the document and line where it was found
- Status sync: when a document is reprocessed, task completion state is updated from checkbox state
- API and iOS views for browsing and filtering tasks

## Relevant Files

### New Lambda Functions
- `lambda/functions/extract_tasks/handler.clj` — Task extraction from document content
- `lambda/functions/api_tasks/handler.clj` — Task listing and management API

### New Shared Libraries
- `lambda/shared/tasks/extractor.clj` — Regex and AI-based task detection

### iOS (new)
- `ios/PKMReader/Features/Tasks/TaskListView.swift` — Task list with filtering
- `ios/PKMReader/Features/Tasks/TaskListViewModel.swift` — Task data management
- `ios/PKMReader/Models/ExtractedTask.swift` — Task model

### Terraform
- `terraform/task_extraction.tf` — Lambda definitions, API routes

### Modified Files
- `terraform/eventbridge.tf` — Add extract_tasks to processing pipeline
- `lambda/build.clj` — Add new function targets

## Acceptance Criteria

- [ ] Markdown checkboxes (`- [ ]`, `- [x]`) extracted as tasks with completion status
- [ ] TODO/ACTION/FIXME markers extracted from document text
- [ ] AI-assisted extraction identifies implicit tasks in meeting notes
- [ ] Tasks stored in DynamoDB with source document reference
- [ ] API endpoint lists tasks with filtering by status, source, and date range
- [ ] Task completion state syncs when source document is reprocessed
- [ ] iOS task list view with status filtering and source document navigation
- [ ] Unit tests cover extraction patterns and API handlers
- [ ] All existing tests continue to pass

## Implementation Steps

- [ ] Step 1: Design DynamoDB key schema for extracted tasks
- [ ] Step 2: Create regex-based task extractor for checkboxes and markers
- [ ] Step 3: Create AI-assisted task extractor using Bedrock
- [ ] Step 4: Create extract_tasks Lambda handler
- [ ] Step 5: Add to EventBridge processing pipeline
- [ ] Step 6: Create task listing API Lambda
- [ ] Step 7: Add Terraform infrastructure
- [ ] Step 8: Create iOS task model and view model
- [ ] Step 9: Create TaskListView with filtering
- [ ] Step 10: Write unit tests
