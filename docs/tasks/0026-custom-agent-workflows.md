# Task 0026: Custom Agent Workflows

**Status**: Planned

## Specifications

Allow users to define custom AI agent workflows — configurable automation rules that trigger on specific events and execute AI-powered processing with user-defined prompts. This generalizes the pattern established by existing Lambdas (classify, summarize, extract) into a user-configurable framework where users can create their own processing rules.

### Workflow Definition

Each workflow specifies:
- **Trigger**: What event starts the workflow (new document, classification match, schedule, manual, @command)
- **Filter**: Optional conditions (document path prefix, tags, classification type)
- **Prompt template**: User-defined prompt with variable interpolation (`{{document.content}}`, `{{document.tags}}`, `{{entity.names}}`)
- **Model**: Which Bedrock model to use (Haiku for fast, Sonnet for complex)
- **Output destination**: Where to write results (`_agent/workflows/{workflow-id}/`, DynamoDB, or notification)

### Example Workflows

- "When a document is classified as 'meeting', extract action items and write to `_agent/actions/`"
- "Every Monday, summarize all documents tagged #project-x from the past week"
- "When @workflow:research is detected, perform deep analysis using Sonnet and write report"

**Depends on:** Task 0023 (Command Interface) for @command-triggered workflows.

## Relevant Files

### New Lambda Functions
- `lambda/functions/workflow_execute/handler.clj` — Execute a workflow with context
- `lambda/functions/api_workflows/handler.clj` — CRUD API for workflow definitions

### New Shared Libraries
- `lambda/shared/workflow/engine.clj` — Template interpolation and execution orchestration
- `lambda/shared/workflow/triggers.clj` — Trigger matching logic

### Terraform
- `terraform/workflows.tf` — Lambda functions, API routes, EventBridge integration

### iOS (new)
- `ios/PKMReader/Features/Workflows/WorkflowListView.swift` — Workflow management UI
- `ios/PKMReader/Features/Workflows/WorkflowFormView.swift` — Create/edit workflow
- `ios/PKMReader/Models/Workflow.swift` — Workflow model

## Acceptance Criteria

- [ ] Workflows can be created, listed, updated, and deleted via API
- [ ] Workflows trigger on configured events (document creation, schedule, manual, @command)
- [ ] Prompt templates support variable interpolation with document and entity data
- [ ] Workflow output written to configured destination
- [ ] iOS UI for managing workflows with form for trigger, filter, prompt, and output
- [ ] Unit tests cover template interpolation, trigger matching, and API handlers
- [ ] All existing tests continue to pass

## Implementation Steps

- [ ] Step 1: Design workflow definition schema and DynamoDB key structure
- [ ] Step 2: Create template interpolation engine
- [ ] Step 3: Create trigger matching logic for event-driven execution
- [ ] Step 4: Create workflow execution Lambda
- [ ] Step 5: Create workflow CRUD API Lambda
- [ ] Step 6: Add EventBridge integration for event-triggered workflows
- [ ] Step 7: Add Terraform infrastructure
- [ ] Step 8: Create iOS workflow management views
- [ ] Step 9: Write unit tests
