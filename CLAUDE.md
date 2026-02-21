# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Development workflow rules

- Always start work in a new git worktree. 
- Never commit or push changes directly to main, all changes must be submitted via PR.
- Before opening a new PR or pushing changes to an existing PR: Run all applicable tests and checks, including linting.
- After creating a PR: Wait for review comments, resolve them, and ensure all CI jobs pass before considering the work done.


## Project Overview

Serverless AWS system for Personal Knowledge Management (PKM). Automatically processes markdown documents from an Obsidian vault: classifies them, extracts entities, and generates daily summaries and weekly reports using Claude models via Amazon Bedrock.

## Common Commands

All Lambda development happens in the `lambda/` directory:

```bash
cd lambda
bb test              # Run all unit tests
bb repl              # Start nREPL for interactive development
bb clean             # Remove build artifacts
```

Build Lambda functions (from `lambda/` directory):
```bash
bb build.clj                      # Build all functions
bb build.clj extract_metadata     # Build single function
```
Output ZIPs are placed in `lambda/target/`.

## Deployment

Deployments happen automatically via CI/CD after PRs are merged to `main`. Do NOT build or deploy manually. Instead:
1. Run tests locally (`bb test` in `lambda/`)
2. Commit to a feature branch and open a PR
3. CI runs tests and Terraform plan on the PR
4. After merge to `main`, CI builds, applies Terraform, and deploys

View Lambda logs (specify function name):
```bash
aws logs tail /aws/lambda/pkm-agent-classify-document --follow
```

## Architecture

** Development Context **

- See @docs/ROADMAP.md for current status and next steps.
- Task based development workflow with numbered tasks in `docs/tasks` directory
- ** Current Status **: In progress functional implementation. 

```
Local Vault → rclone (5min sync) → S3 → EventBridge → Lambda → Bedrock (Claude)
                                                         ↓
                                                    DynamoDB
                                                         ↓
                              _agent/ outputs ← rclone ←─┘
```

**28 Lambda Functions** (all Babashka/Clojure):

Processing (11):
- `extract_metadata` - Parse frontmatter, tags, links
- `classify_document` - AI classification (meeting/idea/reference/journal/project)
- `extract_entities` - Named entity extraction (people, orgs, concepts, locations)
- `generate_daily_summary` - Daily activity summaries (6 AM UTC)
- `generate_weekly_report` - Weekly analysis (8 PM UTC Sunday)
- `update_classification_index` - Maintain classification index (scheduled every 6 hours)
- `bulk_reclassify` - Bulk reclassification with dry-run mode and filtering
- `delete_document` - Cascade-delete DynamoDB records on S3 object deletion
- `index_embeddings` - Generate vector embeddings for semantic search
- `persistent_search_execute` - Execute persistent search monitors via Brave Search API
- `persistent_search_summarize` - AI-driven summarization of search results

Mobile API (17):
- `api_list_documents` - List documents with optional classification filter
- `api_get_document` - Get document with content
- `api_search` - Search by title, path, tags (keyword and semantic modes)
- `api_list_tags` - List all tags with counts
- `api_documents_by_tag` - Get documents by specific tag
- `api_list_classifications` - List classification types with counts
- `api_list_summaries` - List daily AI summaries
- `api_list_reports` - List weekly AI reports
- `api_update_classification` - Classification feedback/correction (PUT)
- `api_bulk_reclassify` - Trigger bulk reclassification (POST)
- `api_create_document` - Create new document (admin only, POST)
- `api_update_document` - Update existing document (admin only, PUT)
- `api_delete_document` - Delete document (admin only, DELETE)
- `api_graph_data` - Entity relationship graph data (GET)
- `api_search_monitors` - List persistent search monitors (GET)
- `api_search_monitor_detail` - Get search monitor detail (GET)
- `api_search_summaries` - List search result summaries (GET)

**Bedrock Models** (defined in `terraform/variables.tf`):
- Haiku 4.5: Fast classification and extraction
- Sonnet 4.5: Summaries and reports

## Code Structure

```
lambda/
├── shared/aws/           # AWS SDK wrappers (bedrock.clj, dynamodb.clj, s3.clj)
├── shared/api/           # API response utilities (response.clj)
├── shared/markdown/      # Markdown parsing utilities
├── functions/            # 28 Lambda function implementations
└── tests/                # Unit tests (99 tests, 646 assertions)

terraform/                # All AWS infrastructure
├── lambda.tf             # Processing Lambda functions
├── api_lambda.tf         # API Lambda functions
├── api_gateway.tf        # HTTP API Gateway with JWT auth
├── cognito.tf            # User Pool and Identity Pool
└── ...                   # S3, DynamoDB, EventBridge, Step Functions

scripts/                  # Deployment and testing
├── deploy.sh, setup-sync.sh, test-workflow.sh
├── test-api.sh           # API integration tests
├── create-cognito-user.sh # Create test users
├── configure-ios.sh      # iOS app configuration
├── cleanup-old-builds.sh # Remove old Lambda build artifacts
├── backfill.clj          # Backfill unprocessed S3 documents
├── bulk-reclassify.sh    # CLI for bulk reclassification
├── cleanup-orphans.clj   # Remove orphaned DynamoDB records
├── fix-dates.clj         # Fix document date metadata
└── index-embeddings.clj  # Build/update vector search index

ios/                      # iOS app (PKMReader)
├── PKMReader/            # SwiftUI app source
│   └── Core/Testing/     # Mock services for UI tests
├── PKMReaderTests/       # Unit tests, snapshots, performance benchmarks
├── PKMReaderUITests/     # UI tests (Page Object pattern)
├── fastlane/             # Build automation
└── project.yml           # XcodeGen project definition

.github/workflows/        # CI/CD pipelines
├── build.yml             # Lambda build pipeline
├── test.yml              # Lambda test pipeline
├── ios-build.yml         # iOS build pipeline
├── ios-test.yml          # iOS test pipeline
└── claude.yml            # Claude Code automation
```

## Key Patterns

**Lambda Handler Pattern** (see `lambda/functions/extract_metadata/handler.clj`):
- Uses `bblf` (Babashka Lambda Framework)
- Receives S3 events via EventBridge
- Returns results to DynamoDB and/or S3 `_agent/` directory

**Bedrock Client** (`lambda/shared/aws/bedrock.clj`):
- Uses awyeah-api for AWS SDK
- Wraps Claude model invocation with retry logic

**Build System** (`lambda/build.clj`):
- Creates Lambda ZIPs with embedded Babashka binary and uberjar
- Uses `bblf` (Babashka Lambda Framework) for runtime
- Bootstrap script invokes `bb -jar lambda.jar -m bblf.runtime handler/handler`

**API Handler Pattern** (see `lambda/functions/api_list_documents/handler.clj`):
- Receives API Gateway events with JWT claims
- Uses `api.response` utilities for consistent responses
- Returns JSON with appropriate HTTP status codes
