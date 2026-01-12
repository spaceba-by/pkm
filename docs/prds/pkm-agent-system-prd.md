# Product Requirements Document: Personal Knowledge Management Agent System

## Overview

Build an AWS-based agent system that processes markdown files from an Obsidian-style personal knowledge management (PKM) vault, performing automated information extraction, classification, summarization, and reporting. The system uses S3 as the source of truth with bidirectional sync to local devices.

## Goals

1. Automate extraction of metadata, entities, and relationships from PKM markdown files
2. Classify documents by type (meeting, idea, reference, journal, project)
3. Generate daily and weekly summary reports
4. Maintain agent-generated content within the vault for easy access via neovim
5. Provide event-driven processing with minimal latency
6. Keep costs low (target <$20/month for typical PKM usage)

## Architecture

### Core Components

**Storage Layer**
- S3 bucket as source of truth for all markdown files
- DynamoDB table for metadata, classifications, and extracted entities
- Supports standard Obsidian vault structure with user content and `_agent/` subdirectory for generated content

**Processing Layer**
- Lambda functions for discrete agent tasks
- Step Functions for multi-step workflows (weekly reports)
- Amazon Bedrock (Claude models) for LLM operations
- EventBridge for event routing and scheduling

**Sync Layer**
- rclone for bidirectional sync between local filesystem and S3
- Supports macOS (primary) and iOS (periodic) sync
- Conflict resolution strategy: newer wins, conflicts renamed

### Data Flow

```
Local Edit → rclone → S3 → EventBridge → Lambda → Bedrock → DynamoDB
                                                         ↓
                                                    S3 (agent outputs) → rclone → Local
```

## Functional Requirements

### FR1: Document Processing Pipeline

**FR1.1: Real-time Classification**
- Trigger: S3 PUT event for any `.md` file in vault
- Extract frontmatter (tags, dates, metadata)
- Call Bedrock (Haiku) to classify document type
- Store classification in DynamoDB
- Update classification index in `_agent/classifications/index.md`

**FR1.2: Entity Extraction**
- Trigger: S3 PUT event for `.md` files
- Extract named entities: people, organizations, concepts, dates
- Parse wikilinks and backlinks for graph relationships
- Store entities in DynamoDB with references to source documents
- Create/update entity pages in `_agent/entities/{type}/{name}.md`

**FR1.3: Metadata Extraction**
- Parse frontmatter YAML
- Extract creation/modification timestamps
- Parse internal links (`[[link]]` syntax)
- Store in DynamoDB for fast querying

### FR2: Daily Summarization

**FR2.1: Scheduled Daily Summary**
- Trigger: EventBridge cron (daily at 6:00 AM user's timezone)
- Query DynamoDB for documents created/modified in last 24 hours
- Call Bedrock (Sonnet) to generate summary
- Write summary to `_agent/summaries/YYYY-MM-DD.md`
- Include wikilinks to source documents

**FR2.2: Summary Format**
```markdown
---
generated: ISO_TIMESTAMP
agent: summarization
period: daily
source_docs: COUNT
tags: [agent-generated, summary]
---

# Daily Summary - YYYY-MM-DD

{SUMMARY_CONTENT}

## Source Documents
- [[path/to/doc1.md]]
- [[path/to/doc2.md]]

---
*Generated automatically by PKM agent*
```

### FR3: Weekly Reporting

**FR3.1: Scheduled Weekly Report**
- Trigger: EventBridge cron (Sunday 8:00 PM user's timezone)
- Step Function orchestrates multi-stage report generation
- Query DynamoDB for week's activity
- Generate sections: overview, activity summary, daily highlights, themes, follow-ups
- Write report to `_agent/reports/weekly/YYYY-Www.md`

**FR3.2: Report Structure**
- Overview: 2-3 sentence summary of week's activity
- Activity metrics: document counts, new projects, completed tasks
- Daily highlights: link to each day's summary
- Key themes: patterns identified across documents
- Recommended follow-ups: 3-5 suggested actions

### FR4: Classification Index

**FR4.1: Maintain Classification Index**
- Update `_agent/classifications/index.md` on each classification
- Group documents by type
- Sort alphabetically within each type
- Include wikilinks to classified documents

**FR4.2: Index Format**
```markdown
---
generated: ISO_TIMESTAMP
tags: [index, agent-generated]
---

# Document Classifications

## Meeting
- [[path/to/meeting1.md]]
- [[path/to/meeting2.md]]

## Idea
- [[path/to/idea1.md]]

...
```

### FR5: Sync Configuration

**FR5.1: rclone Setup**
- Provide rclone config template for S3 remote
- Provide launchd plist for macOS scheduled sync (every 5 minutes)
- Conflict resolution: `--conflict-resolve newer --conflict-loser rename`
- Support for manual sync command: `pkm-sync` alias

**FR5.2: iOS Sync Guidance**
- Document Obsidian mobile + "Remotely Save" plugin setup
- Alternative: a-Shell + rclone + Shortcuts automation
- Target: hourly or on-demand sync acceptable

### FR6: Entity Management

**FR6.1: Entity Page Creation**
- Create entity pages in `_agent/entities/{type}/{name}.md`
- Types: people, organizations, concepts, locations
- Include list of source documents mentioning entity
- Update existing entity pages with new mentions

**FR6.2: Entity Page Format**
```markdown
---
type: person
mentioned_in:
  - [[path/to/doc1.md]]
  - [[path/to/doc2.md]]
last_updated: ISO_TIMESTAMP
---

# {ENTITY_NAME}

## Mentions
- [[path/to/doc1.md]] - {context snippet}
- [[path/to/doc2.md]] - {context snippet}
```

## Non-Functional Requirements

### NFR1: Performance
- Classification latency: < 5 seconds from S3 PUT to DynamoDB update
- Daily summary generation: < 30 seconds
- Weekly report generation: < 2 minutes
- Sync latency: < 10 seconds for changes to propagate to S3

### NFR2: Cost
- Target monthly cost: < $20 for typical usage (50-100 docs/month)
- Use Bedrock Haiku for high-volume operations (classification, extraction)
- Use Bedrock Sonnet for quality-critical operations (summaries, reports)
- DynamoDB on-demand pricing
- S3 standard storage (markdown files are small)

### NFR3: Reliability
- Idempotent Lambda functions (safe to retry)
- DLQ for failed Lambda invocations
- CloudWatch alarms for processing failures
- S3 versioning enabled for vault bucket

### NFR4: Security
- S3 bucket encryption at rest
- IAM roles with least privilege
- No public access to S3 bucket
- Bedrock API calls within VPC (optional, for additional security)

### NFR5: Observability
- CloudWatch Logs for all Lambda functions
- CloudWatch Metrics for processing counts and latencies
- X-Ray tracing for Step Functions
- SNS notifications for weekly report completion (optional)

## Data Schema

### DynamoDB Table: `pkm-metadata`

**Primary Key:**
- PK (String): `doc#{file_path}` or `tag#{tag_name}` or `entity#{type}#{name}`
- SK (String): `metadata` or `doc#{file_path}` or `mention#{doc_path}`

**Attributes:**
- `title` (String): Document title
- `created` (String): ISO timestamp
- `modified` (String): ISO timestamp
- `tags` (List): List of tag strings
- `classification` (String): Document type
- `entities` (List): Extracted entities
- `summary` (String): Short summary
- `links_to` (List): Outbound wikilinks
- `linked_from` (List): Inbound wikilinks

**GSI: tag-index**
- PK: `tag#{tag_name}`
- SK: `doc#{file_path}`

**GSI: classification-index**
- PK: `classification#{type}`
- SK: `modified` (for sorting by recency)

**GSI: entity-index**
- PK: `entity#{type}#{name}`
- SK: `doc#{file_path}`

### S3 Bucket Structure

```
s3://pkm-vault/
├── daily/
│   └── 2026-01-10.md
├── projects/
│   └── project-name.md
├── reference/
│   └── topic.md
├── _agent/
│   ├── summaries/
│   │   └── 2026-01-10.md
│   ├── reports/
│   │   ├── daily/
│   │   │   └── 2026-01-10.md
│   │   └── weekly/
│   │       └── 2026-W02.md
│   ├── entities/
│   │   ├── people/
│   │   │   └── john-doe.md
│   │   ├── organizations/
│   │   │   └── acme-corp.md
│   │   └── concepts/
│   │       └── machine-learning.md
│   └── classifications/
│       └── index.md
└── .obsidian/
    └── (excluded from processing)
```

## Technical Specifications

### Lambda Functions

**1. `classify-document`**
- Runtime: Python 3.12
- Memory: 512 MB
- Timeout: 30 seconds
- Trigger: EventBridge rule (S3 PUT events for `*.md`)
- Bedrock model: Claude 3 Haiku
- Outputs: DynamoDB update, classification index update

**2. `extract-entities`**
- Runtime: Python 3.12
- Memory: 512 MB
- Timeout: 30 seconds
- Trigger: EventBridge rule (S3 PUT events for `*.md`)
- Bedrock model: Claude 3 Haiku
- Outputs: DynamoDB updates, entity pages in S3

**3. `extract-metadata`**
- Runtime: Python 3.12
- Memory: 256 MB
- Timeout: 10 seconds
- Trigger: EventBridge rule (S3 PUT events for `*.md`)
- No Bedrock calls (pure parsing)
- Outputs: DynamoDB updates

**4. `generate-daily-summary`**
- Runtime: Python 3.12
- Memory: 1024 MB
- Timeout: 60 seconds
- Trigger: EventBridge cron (daily 6:00 AM)
- Bedrock model: Claude 3.5 Sonnet
- Outputs: Summary markdown in S3

**5. `generate-weekly-report`**
- Runtime: Python 3.12
- Memory: 2048 MB
- Timeout: 120 seconds
- Trigger: Step Function (invoked by EventBridge cron)
- Bedrock model: Claude 3.5 Sonnet
- Outputs: Weekly report markdown in S3

**6. `update-classification-index`**
- Runtime: Python 3.12
- Memory: 256 MB
- Timeout: 30 seconds
- Trigger: Direct invocation from `classify-document`
- Outputs: Classification index markdown in S3

### EventBridge Rules

**1. `s3-markdown-events`**
- Event pattern: S3 PUT for `*.md` files (excluding `_agent/` directory)
- Targets: `classify-document`, `extract-entities`, `extract-metadata`

**2. `daily-summary-schedule`**
- Schedule: `cron(0 6 * * ? *)` (6:00 AM daily, UTC)
- Target: `generate-daily-summary`

**3. `weekly-report-schedule`**
- Schedule: `cron(0 20 ? * SUN *)` (8:00 PM Sunday, UTC)
- Target: Step Function `generate-weekly-report-workflow`

### Step Function: `generate-weekly-report-workflow`

**States:**
1. Query week's activity from DynamoDB
2. Parallel state:
   - Generate activity metrics
   - Generate theme analysis
   - Generate follow-up recommendations
3. Synthesize report from parallel outputs
4. Write report to S3
5. (Optional) Send SNS notification

### IAM Roles

**Lambda Execution Role:**
- S3: GetObject, PutObject on vault bucket
- DynamoDB: GetItem, PutItem, Query, Scan on metadata table
- Bedrock: InvokeModel on Claude models
- CloudWatch: CreateLogGroup, CreateLogStream, PutLogEvents
- X-Ray: PutTraceSegments, PutTelemetryRecords

**Step Function Execution Role:**
- Lambda: InvokeFunction
- CloudWatch: CreateLogGroup, CreateLogStream, PutLogEvents
- X-Ray: PutTraceSegments, PutTelemetryRecords

### Bedrock Configuration

**Models:**
- Classification & Extraction: `anthropic.claude-3-haiku-20240307-v1:0`
- Summaries & Reports: `anthropic.claude-3-5-sonnet-20241022-v2:0`

**Prompt Templates:**

*Classification Prompt:*
```
Classify this markdown document into exactly one of these categories:
- meeting (notes from meetings or calls)
- idea (brainstorms, concepts, proposals)
- reference (documentation, how-tos, factual info)
- journal (personal reflections, daily logs)
- project (project plans, specs, tracking)

Return ONLY the category name, nothing else.

Document:
{content}
```

*Entity Extraction Prompt:*
```
Extract named entities from this markdown document.
Return valid JSON only, no other text:
{
  "people": ["name1", "name2"],
  "organizations": ["org1", "org2"],
  "concepts": ["concept1", "concept2"],
  "locations": ["place1", "place2"]
}

Document:
{content}
```

*Daily Summary Prompt:*
```
Analyze these documents created or modified today and provide a concise summary.
Focus on: key themes, important updates, decisions made, and action items.
Write in second person ("You worked on...", "You decided...").
Keep it under 500 words.

Documents:
{documents}
```

*Weekly Report Prompt:*
```
Analyze this week's PKM activity and provide:

1. Overview: 2-3 sentences summarizing the week
2. Key Themes: 3-5 major themes across documents
3. Recommended Follow-ups: 3-5 specific actions to take

Base your analysis on these documents and daily summaries:
{week_data}

Format your response in markdown suitable for a weekly review.
```

## Infrastructure as Code

### Terraform Structure

```
terraform/
├── main.tf (provider, backend config)
├── s3.tf (vault bucket, versioning, lifecycle)
├── dynamodb.tf (metadata table, GSIs)
├── lambda.tf (function definitions, layers)
├── eventbridge.tf (rules, targets)
├── stepfunctions.tf (state machine definition)
├── iam.tf (roles, policies)
├── cloudwatch.tf (log groups, alarms, dashboards)
└── variables.tf (bucket name, region, etc.)
```

### Key Terraform Outputs

- `s3_bucket_name`: Name of vault bucket
- `rclone_remote_config`: rclone config snippet for S3 remote
- `dynamodb_table_name`: Name of metadata table
- `lambda_function_names`: Map of Lambda function names
- `sync_command`: Example rclone sync command

## Repository Structure

```
pkm-agent-system/
├── README.md
├── docs/
│   ├── setup.md (AWS setup, credentials)
│   ├── sync-guide.md (rclone setup for macOS/iOS)
│   ├── architecture.md (diagrams, flow charts)
│   └── prompts.md (Bedrock prompt templates)
├── terraform/
│   ├── main.tf
│   ├── s3.tf
│   ├── dynamodb.tf
│   ├── lambda.tf
│   ├── eventbridge.tf
│   ├── stepfunctions.tf
│   ├── iam.tf
│   ├── cloudwatch.tf
│   └── variables.tf
├── lambda/
│   ├── requirements.txt (boto3, etc.)
│   ├── shared/
│   │   ├── __init__.py
│   │   ├── bedrock_client.py
│   │   ├── dynamodb_client.py
│   │   ├── s3_client.py
│   │   └── markdown_utils.py
│   ├── classify_document/
│   │   ├── handler.py
│   │   └── prompts.py
│   ├── extract_entities/
│   │   ├── handler.py
│   │   └── prompts.py
│   ├── extract_metadata/
│   │   └── handler.py
│   ├── generate_daily_summary/
│   │   ├── handler.py
│   │   └── prompts.py
│   ├── generate_weekly_report/
│   │   ├── handler.py
│   │   └── prompts.py
│   └── update_classification_index/
│       └── handler.py
├── stepfunctions/
│   └── weekly_report_workflow.json
├── scripts/
│   ├── deploy.sh (terraform apply + lambda packaging)
│   ├── setup-sync.sh (generate rclone config, launchd plist)
│   └── test-workflow.sh (test Lambda functions locally)
├── sync/
│   ├── rclone.conf.template
│   ├── com.pkm.sync.plist.template (macOS launchd)
│   └── README.md
├── tests/
│   ├── unit/
│   │   ├── test_classify_document.py
│   │   ├── test_extract_entities.py
│   │   └── test_markdown_utils.py
│   └── integration/
│       ├── test_full_pipeline.py
│       └── fixtures/
│           └── sample.md
└── .gitignore
```

## Development Phases

### Phase 1: Infrastructure Setup
- S3 bucket creation with versioning
- DynamoDB table with GSIs
- Basic IAM roles and policies
- EventBridge S3 event routing
- Deploy with Terraform

### Phase 2: Core Processing
- Implement `extract-metadata` Lambda
- Implement `classify-document` Lambda
- Implement `extract-entities` Lambda
- Test with sample markdown files
- Validate DynamoDB writes

### Phase 3: Summarization
- Implement `generate-daily-summary` Lambda
- Create EventBridge daily schedule
- Test summary generation and S3 write-back
- Validate markdown formatting

### Phase 4: Reporting
- Implement `generate-weekly-report` Lambda
- Create Step Function workflow
- Create EventBridge weekly schedule
- Test end-to-end weekly report generation

### Phase 5: Indexing
- Implement `update-classification-index` Lambda
- Implement entity page creation/updates
- Test index maintenance
- Validate wikilink generation

### Phase 6: Sync Setup
- Document rclone installation and configuration
- Create launchd plist for macOS
- Document iOS sync options
- Test bidirectional sync with conflict resolution
- Create setup scripts

### Phase 7: Observability
- CloudWatch dashboards
- CloudWatch alarms for failures
- SNS notifications (optional)
- Cost monitoring

## Testing Strategy

### Unit Tests
- Markdown parsing functions
- Frontmatter extraction
- Wikilink parsing
- DynamoDB client operations
- S3 client operations
- Bedrock prompt formatting

### Integration Tests
- End-to-end document classification
- Entity extraction and page creation
- Daily summary generation
- Weekly report workflow
- S3 event triggering

### Test Fixtures
- Sample markdown documents (various types)
- Sample DynamoDB query responses
- Sample Bedrock API responses (mocked)

## Success Metrics

### Functional Metrics
- Classification accuracy: > 90% (manual validation)
- Entity extraction recall: > 80%
- Daily summary generation: 100% success rate
- Weekly report generation: 100% success rate
- Sync reliability: 99.9% success rate

### Performance Metrics
- Average classification latency: < 3 seconds
- Average daily summary generation: < 20 seconds
- Average weekly report generation: < 90 seconds
- P99 sync latency: < 15 seconds

### Cost Metrics
- Monthly AWS cost: < $20 for 100 docs/month
- Cost per document processed: < $0.05

## Future Enhancements (Out of Scope)

- Semantic search over vault (OpenSearch/Kendra)
- Interactive chat interface to query PKM
- Automated task extraction and tracking
- Integration with calendar/email for context
- Mobile app for on-the-go capture
- Real-time collaboration features
- Advanced knowledge graph visualization
- Custom agent workflows (user-defined)

## Appendices

### Appendix A: Sample rclone Configuration

```ini
[pkm-s3]
type = s3
provider = AWS
env_auth = true
region = us-east-1
acl = private
```

### Appendix B: Sample launchd Plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.pkm.sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/rclone</string>
        <string>bisync</string>
        <string>/Users/USERNAME/vault</string>
        <string>pkm-s3:BUCKET_NAME/vault</string>
        <string>--conflict-resolve</string>
        <string>newer</string>
        <string>--conflict-loser</string>
        <string>rename</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

### Appendix C: Sample Document Formats

**User Document:**
```markdown
---
title: Project Kickoff Meeting
date: 2026-01-10
tags: [meeting, project-alpha]
attendees: [Alice, Bob]
---

# Project Kickoff

Discussed initial requirements for Project Alpha...

## Action Items
- [ ] Alice to draft technical spec
- [ ] Bob to setup repository

## Next Steps
Follow-up meeting scheduled for 2026-01-17.
```

**Agent-Generated Summary:**
```markdown
---
generated: 2026-01-11T06:00:00Z
agent: summarization
period: daily
source_docs: 3
tags: [agent-generated, summary]
---

# Daily Summary - 2026-01-10

You had a productive day focusing on Project Alpha. The kickoff meeting established clear requirements and action items. You also captured several ideas for improving the onboarding process and documented reference material on AWS Lambda best practices.

Key highlights:
- Project Alpha kicked off with technical requirements defined
- Three new ideas documented for Q1 initiatives
- Updated reference docs on serverless architecture

## Source Documents
- [[daily/2026-01-10.md]]
- [[projects/project-alpha-kickoff.md]]
- [[ideas/onboarding-improvements.md]]
- [[reference/aws-lambda-best-practices.md]]

---
*Generated automatically by PKM agent*
```

---

## Implementation Notes for Claude Code

This PRD is designed to be comprehensive enough for automated scaffolding. Key priorities:

1. **Start with Terraform infrastructure** - scaffold complete IaC before Lambda code
2. **Shared Lambda utilities** - create reusable modules for S3, DynamoDB, Bedrock
3. **Environment variables** - use for bucket names, table names, region
4. **Error handling** - all Lambda functions should have try/catch and DLQ support
5. **Logging** - structured logging with context (document path, operation type)
6. **Testing** - include pytest setup and sample test cases
7. **Documentation** - comprehensive README with setup instructions
8. **Scripts** - deployment and sync setup should be automated

The repository should be immediately usable after running:
```bash
cd terraform && terraform apply
cd ../scripts && ./setup-sync.sh
```
