# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

Deploy infrastructure:
```bash
cd terraform
terraform plan       # Preview changes
terraform apply      # Deploy
```

View Lambda logs (specify function name):
```bash
aws logs tail /aws/lambda/pkm-agent-classify-document --follow
```

## Architecture

```
Local Vault → rclone (5min sync) → S3 → EventBridge → Lambda → Bedrock (Claude)
                                                         ↓
                                                    DynamoDB
                                                         ↓
                              _agent/ outputs ← rclone ←─┘
```

**6 Lambda Functions** (all Babashka/Clojure):
- `extract_metadata` - Parse frontmatter, tags, links
- `classify_document` - AI classification (meeting/idea/reference/journal/project)
- `extract_entities` - Named entity extraction (people, orgs, concepts, locations)
- `generate_daily_summary` - Daily activity summaries (6 AM UTC)
- `generate_weekly_report` - Weekly analysis (8 PM UTC Sunday)
- `update_classification_index` - Maintain classification index

**Bedrock Models** (defined in `terraform/variables.tf`):
- Haiku 4.5: Fast classification and extraction
- Sonnet 4.5: Summaries and reports

## Code Structure

```
lambda/
├── shared/aws/           # AWS SDK wrappers (bedrock.clj, dynamodb.clj, s3.clj)
├── shared/markdown/      # Markdown parsing utilities
├── functions/            # 6 Lambda function implementations
└── tests/                # Unit tests

terraform/                # All AWS infrastructure (S3, DynamoDB, Lambda, EventBridge, Step Functions)
scripts/                  # deploy.sh, setup-sync.sh, test-workflow.sh
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
