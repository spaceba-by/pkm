# Task 0025: Self-Improvement Dispatch

**Status**: Done

## Specifications

Enable the PKM system to dispatch TODOs and user-defined tasks to sandboxed Claude Code instances for autonomous execution. When the system extracts tasks (Task 0024) or receives commands (Task 0023) that involve code changes, document generation, or research, it can route these to a Claude Code instance running in an isolated environment. Results are collected and written back to the PKM vault.

This is the "self-improvement" capability — the system can act on its own development TODOs by dispatching them to an AI coding agent, reviewing the output, and integrating results.

### Architecture

```
Task Source (extracted TODO, @command, manual trigger)
    ↓
dispatch_job Lambda
    ↓ creates job record in DynamoDB
    ↓ provisions sandbox (ECS Fargate task or Lambda container)
    ↓ passes task description, context, and credentials
Sandbox Environment
    ↓ Claude Code executes task
    ↓ produces artifacts (code, documents, reports)
    ↓ writes results to S3
collect_results Lambda
    ↓ reads sandbox output from S3
    ↓ updates job record with status and artifacts
    ↓ writes summary to _agent/dispatch/{job-id}/result.md
```

### Key Capabilities

- Job queue with status tracking (pending, running, completed, failed)
- Sandboxed execution in ECS Fargate for isolation
- Configurable context injection (relevant documents, code files)
- Result collection and vault integration
- Job history and artifact browsing via API

**Depends on:** Task 0023 (Command Interface) for routing commands, Task 0024 (Task Extraction) for automated task sourcing.

## Relevant Files

### New Lambda Functions
- `lambda/functions/dispatch_job/handler.clj` — Create and submit dispatch jobs (ECS Fargate or local agent target)
- `lambda/functions/collect_results/handler.clj` — Collect sandbox output and update records (EventBridge ECS task-stopped trigger)
- `lambda/functions/api_list_jobs/handler.clj` — GET /dispatch/jobs
- `lambda/functions/api_get_job/handler.clj` — GET /dispatch/jobs/{jobId}
- `lambda/functions/api_create_job/handler.clj` — POST /dispatch/jobs
- `lambda/functions/api_claim_job/handler.clj` — POST /dispatch/jobs/claim (local agent polling)
- `lambda/functions/api_complete_job/handler.clj` — POST /dispatch/jobs/{jobId}/complete (local agent result submission)
- `lambda/functions/api_agent_types/handler.clj` — GET/POST/DELETE /dispatch/agent-types

### Terraform
- `terraform/dispatch.tf` — ECS Fargate cluster and task definition, Lambda functions, API routes, IAM (gated by `enable_dispatch` flag)

### iOS (new)
- `ios/PKMReader/Features/Dispatch/DispatchListView.swift` — Job history view
- `ios/PKMReader/Features/Dispatch/DispatchDetailView.swift` — Job detail view
- `ios/PKMReader/Features/Dispatch/DispatchListViewModel.swift` — Job list view model
- `ios/PKMReader/Models/DispatchJob.swift` — Job model

### Tests
- `lambda/tests/dispatch/dispatch_job_test.clj`, `collect_results_test.clj`, `api_test.clj`

## Implementation Notes

The implementation extends the original spec with a second execution target: in addition to sandboxed ECS Fargate tasks, jobs can be claimed and executed by a local agent polling the API (POST /dispatch/jobs/claim and POST /dispatch/jobs/{jobId}/complete), for private-network or low-cost execution. Agent type records in DynamoDB define the execution configuration per job type. All dispatch infrastructure is gated by the `enable_dispatch` Terraform flag.

## Acceptance Criteria

- [x] Jobs can be created from extracted tasks or manual command input
- [x] Sandbox environment provisioned with appropriate isolation
- [x] Claude Code instance receives task context and executes autonomously
- [x] Results collected from sandbox and written to PKM vault
- [x] Job status tracked through lifecycle (pending → running → completed/failed)
- [x] API endpoint for listing jobs and viewing results
- [x] iOS view for browsing dispatch history
- [x] Unit tests cover dispatch and collection logic
- [x] All existing tests continue to pass

## Implementation Steps

- [x] Step 1: Design job record schema and DynamoDB key structure
- [x] Step 2: Create ECS Fargate task definition for sandbox environment
- [x] Step 3: Create dispatch_job Lambda with job creation and sandbox provisioning
- [x] Step 4: Create collect_results Lambda triggered on sandbox completion
- [x] Step 5: Add result writing to S3 `_agent/dispatch/` path
- [x] Step 6: Create API endpoints for job management
- [x] Step 7: Add Terraform infrastructure
- [x] Step 8: Create iOS dispatch history view
- [x] Step 9: Write unit tests
