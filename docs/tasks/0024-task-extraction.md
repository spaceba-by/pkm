# Task 0024: Automated Task Extraction

**Status**: In Progress

## Specifications

Automatically detect and extract TODOs, action items, and tasks from processed documents. Many PKM notes contain actionable items in various formats — markdown checkboxes (`- [ ]`), inline mentions ("TODO: review proposal"), meeting action items, and deadline references. This task adds an extraction pipeline that identifies these items, structures them, and makes them queryable via API and the iOS app.

### Extraction Approach

A new `extract_tasks` Lambda runs as part of the document processing pipeline (parallel with extract_metadata, classify_document, extract_entities). It uses a combination of regex pattern matching for common formats and Bedrock AI for natural language task detection (only for meeting/project documents). Extracted tasks reference their source document and include metadata like due dates, priority, and completion status.

### Task Data Model

Tasks are stored in DynamoDB using two patterns:
1. Embedded `tasks` list on the document METADATA item
2. Task index entries for cross-document querying (`task#open` / `task#completed` partitions)

```
task_id: String (deterministic hash: "t-<8hex>")
description: String
status: "open" | "completed"
source: "pattern" | "ai"
marker: "checkbox" | "todo" | "action" | "fixme" | "implicit"
document_path: String (S3 key)
line_number: Int?
due_date: String? (ISO-8601)
priority: "high" | "medium" | "low" | nil
context: String? (surrounding text from source)
```

### Key Capabilities

- Pattern-based extraction: markdown checkboxes, "TODO:", "ACTION:", "FIXME:" markers
- AI-assisted extraction: Bedrock identifies implicit tasks in meeting/project documents only
- Source document linking: each task references the document and line where it was found
- Status sync: when a document is reprocessed, task completion state is updated from checkbox state
- API endpoints: GET /tasks (with status/document filtering), GET /tasks/stats
- iOS: Tasks section in Insights tab with NavigationLink to full task list

## Relevant Files

### New Lambda Functions
- `lambda/functions/extract_tasks/handler.clj` — Task extraction from document content
- `lambda/functions/api_tasks/handler.clj` — Task listing API with pagination
- `lambda/functions/api_tasks_stats/handler.clj` — Task count statistics API

### New Shared Libraries
- `lambda/shared/tasks/extractor.clj` — Pure-function regex and AI-based task detection

### New Tests
- `lambda/tests/tasks/extractor_test.clj` — Extractor unit tests
- `lambda/tests/tasks/api_test.clj` — API response formatting tests

### iOS (new)
- `ios/PKMReader/Features/Tasks/TaskListView.swift` — Task list with filtering and stats
- `ios/PKMReader/Features/Tasks/TaskListViewModel.swift` — Task data management
- `ios/PKMReader/Models/ExtractedTask.swift` — Task model, response types

### Terraform
- `terraform/task_extraction.tf` — Processing Lambda, API Lambdas, EventBridge target, API Gateway routes

### Modified Files
- `terraform/dynamodb.tf` — Added `task-index` GSI (task_status + modified)
- `terraform/lambda.tf` — Added extract-tasks log group
- `terraform/api_lambda.tf` — Added api-tasks, api-tasks-stats log groups
- `lambda/build.clj` — Added extract_tasks, api_tasks, api_tasks_stats
- `lambda/bb.edn` — Added function paths
- `lambda/tests/test_runner.clj` — Added test namespaces
- `lambda/shared/shared/deletion.clj` — Added task index cleanup to cascade delete
- `ios/PKMReader/Core/Networking/APIClientProtocol.swift` — Added listTasks, getTaskStats
- `ios/PKMReader/Core/Networking/APIClient.swift` — Implemented task endpoints
- `ios/PKMReader/Core/Networking/APIEndpoints.swift` — Added task endpoints
- `ios/PKMReader/Core/Networking/APIResponseTypes.swift` — (types in ExtractedTask.swift)
- `ios/PKMReader/Core/Testing/UITestAPIClient.swift` — Added mock task data
- `ios/PKMReaderTests/Mocks/MockAPIClient.swift` — Added task mock methods
- `ios/PKMReader/Features/Insights/InsightsView.swift` — Added Tasks navigation section

## Acceptance Criteria

- [x] Markdown checkboxes (`- [ ]`, `- [x]`) extracted as tasks with completion status
- [x] TODO/ACTION/FIXME markers extracted from document text
- [x] AI-assisted extraction identifies implicit tasks in meeting notes
- [x] Tasks stored in DynamoDB with source document reference
- [x] API endpoint lists tasks with filtering by status, source, and date range
- [x] Task completion state syncs when source document is reprocessed
- [x] iOS task list view with status filtering and source document navigation
- [x] Unit tests cover extraction patterns and API handlers
- [ ] All existing tests continue to pass

## Implementation Steps

- [x] Step 1: Design DynamoDB key schema for extracted tasks
- [x] Step 2: Create regex-based task extractor for checkboxes and markers
- [x] Step 3: Create AI-assisted task extractor using Bedrock
- [x] Step 4: Create extract_tasks Lambda handler
- [x] Step 5: Add to EventBridge processing pipeline (via Terraform)
- [x] Step 6: Create task listing API Lambdas
- [x] Step 7: Add Terraform infrastructure
- [x] Step 8: Create iOS task model and view model
- [x] Step 9: Create TaskListView with filtering, integrate into Insights tab
- [x] Step 10: Write unit tests
