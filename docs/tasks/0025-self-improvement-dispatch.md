# Task 0025: Self-Improvement Dispatch

**Status**: Planned

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
- `lambda/functions/dispatch_job/handler.clj` — Create and submit dispatch jobs
- `lambda/functions/collect_results/handler.clj` — Collect sandbox output and update records

### Terraform
- `terraform/dispatch.tf` — ECS Fargate task definition, Lambda functions, S3 paths, IAM

### iOS (new)
- `ios/PKMReader/Features/Dispatch/DispatchListView.swift` — Job history view
- `ios/PKMReader/Models/DispatchJob.swift` — Job model

## Acceptance Criteria

- [ ] Jobs can be created from extracted tasks or manual command input
- [ ] Sandbox environment provisioned with appropriate isolation
- [ ] Claude Code instance receives task context and executes autonomously
- [ ] Results collected from sandbox and written to PKM vault
- [ ] Job status tracked through lifecycle (pending → running → completed/failed)
- [ ] API endpoint for listing jobs and viewing results
- [ ] iOS view for browsing dispatch history
- [ ] Unit tests cover dispatch and collection logic
- [ ] All existing tests continue to pass

## Implementation Steps

- [ ] Step 1: Design job record schema and DynamoDB key structure
- [ ] Step 2: Create ECS Fargate task definition for sandbox environment
- [ ] Step 3: Create dispatch_job Lambda with job creation and sandbox provisioning
- [ ] Step 4: Create collect_results Lambda triggered on sandbox completion
- [ ] Step 5: Add result writing to S3 `_agent/dispatch/` path
- [ ] Step 6: Create API endpoints for job management
- [ ] Step 7: Add Terraform infrastructure
- [ ] Step 8: Create iOS dispatch history view
- [ ] Step 9: Write unit tests
