# PKM Agent System Architecture

## Overview

The PKM Agent System is a serverless AWS architecture that automatically processes Personal Knowledge Management (PKM) markdown files, providing classification, entity extraction, and intelligent summarization.

## Architecture Diagram

```
┌─────────────────┐
│  Local Vault    │
│   (macOS/iOS)   │
└────────┬────────┘
         │ rclone bisync (every 5 min)
         ▼
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
│                                                              │
│  ┌──────────────┐                                           │
│  │  S3 Bucket   │                                           │
│  │  (Source of  │                                           │
│  │   Truth)     │                                           │
│  └──────┬───────┘                                           │
│         │ S3 Events → EventBridge                           │
│         ▼                                                    │
│  ┌──────────────────────────────────────────────────┐      │
│  │           EventBridge Rules                       │      │
│  │  • s3-markdown-events (PUT *.md)                 │      │
│  │  • daily-summary-schedule (6 AM UTC)             │      │
│  │  • weekly-report-schedule (Sun 8 PM UTC)         │      │
│  └───┬──────────┬──────────────┬───────────────┬────┘      │
│      │          │              │               │            │
│      ▼          ▼              ▼               ▼            │
│  ┌────────┐ ┌────────┐ ┌──────────┐  ┌────────────────┐   │
│  │classify│ │extract │ │extract   │  │daily-summary   │   │
│  │-doc    │ │-entity │ │-metadata │  │                │   │
│  └───┬────┘ └───┬────┘ └────┬─────┘  └────┬───────────┘   │
│      │          │           │              │                │
│      │          │           │              │                │
│      ▼          ▼           ▼              ▼                │
│  ┌──────────────────────────────────────────────┐          │
│  │            DynamoDB Table                     │          │
│  │  PK: doc#path | tag#name | entity#type#name  │          │
│  │  SK: metadata | doc#path | mention#doc       │          │
│  │                                               │          │
│  │  GSI: tag-index, classification-index,       │          │
│  │       entity-index                            │          │
│  └──────────────────────────────────────────────┘          │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │         Amazon Bedrock                        │          │
│  │  • Claude 3 Haiku (classify, extract)        │          │
│  │  • Claude 3.5 Sonnet (summaries, reports)    │          │
│  └──────────────────────────────────────────────┘          │
│                        ▲                                     │
│                        │                                     │
│               All Lambda functions                           │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │         Step Functions                        │          │
│  │  weekly-report-workflow                       │          │
│  │   └─> generate-weekly-report Lambda           │          │
│  └──────────────────────────────────────────────┘          │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │         CloudWatch                            │          │
│  │  • Logs (all Lambda functions)               │          │
│  │  • Metrics Dashboard                          │          │
│  │  • Alarms (errors, throttles, DLQ)           │          │
│  └──────────────────────────────────────────────┘          │
│                                                              │
└──────────────────────────────────────────────────────────────┘
         │
         │ rclone bisync
         ▼
┌─────────────────┐
│  Local Vault    │
│  (_agent/ dir)  │
└─────────────────┘
```

## Components

### 1. Storage Layer

#### S3 Bucket
- **Purpose:** Source of truth for all markdown files
- **Features:**
  - Versioning enabled
  - Server-side encryption (AES256)
  - EventBridge notifications
  - Lifecycle policies for old versions
- **Structure:**
  ```
  s3://bucket/
  ├── daily/           # User content
  ├── projects/
  ├── reference/
  └── _agent/          # Agent-generated content
      ├── summaries/
      ├── reports/
      ├── entities/
      └── classifications/
  ```

#### DynamoDB Table
- **Purpose:** Fast querying of metadata, classifications, entities
- **Primary Key:**
  - PK: `doc#path` | `tag#name` | `entity#type#name`
  - SK: `metadata` | `doc#path` | `mention#doc`
- **Global Secondary Indexes:**
  1. **tag-index:** Query documents by tag
  2. **classification-index:** Query by doc type, sorted by date
  3. **entity-index:** Query docs mentioning specific entities
- **Billing:** On-demand (pay per request)

### 2. Processing Layer

#### Lambda Functions

| Function | Runtime | Memory | Timeout | Trigger | Purpose |
|----------|---------|--------|---------|---------|---------|
| `classify-document` | Babashka | 512 MB | 30s | S3 PUT | Classify doc type using Bedrock |
| `extract-entities` | Babashka | 512 MB | 30s | S3 PUT | Extract named entities |
| `extract-metadata` | Babashka | 256 MB | 10s | S3 PUT | Parse frontmatter, links, tags |
| `generate-daily-summary` | Babashka | 1024 MB | 60s | Cron (6 AM) | Generate daily summary |
| `generate-weekly-report` | Babashka | 2048 MB | 120s | Step Function | Generate weekly report |
| `update-classification-index` | Babashka | 256 MB | 30s | Direct invoke | Update classification index |

**Shared Code:**
- Common utilities in `lambda/shared/`: `aws/bedrock.clj`, `aws/dynamodb.clj`, `aws/s3.clj`, `markdown/utils.clj`
- Bundled into each Lambda's uberjar via `build.clj`
- Uses `bblf` (Babashka Lambda Framework) for runtime

#### Step Functions
- **weekly-report-workflow:**
  1. Invokes `generate-weekly-report` Lambda
  2. Checks for success
  3. Handles errors with retry logic

### 3. Event-Driven Processing

#### EventBridge Rules

1. **s3-markdown-events:**
   - Triggered by: S3 PUT events for `*.md` files
   - Excludes: `_agent/` and `.obsidian/` directories
   - Targets: `classify-document`, `extract-entities`, `extract-metadata`
   - Processing: Parallel (all 3 functions run concurrently)

2. **daily-summary-schedule:**
   - Schedule: `cron(0 6 * * ? *)` (6 AM UTC daily)
   - Target: `generate-daily-summary` Lambda
   - Purpose: Summarize previous day's activity

3. **weekly-report-schedule:**
   - Schedule: `cron(0 20 ? * SUN *)` (8 PM UTC Sundays)
   - Target: `generate-weekly-report-workflow` Step Function
   - Purpose: Generate comprehensive weekly review

### 4. AI/ML Layer

#### Amazon Bedrock

**Models:**
- **Claude 3 Haiku:** High-volume, low-cost operations
  - Document classification
  - Entity extraction
  - Cost: ~$0.25 per 1M input tokens

- **Claude 3.5 Sonnet:** Quality-critical operations
  - Daily summaries
  - Weekly reports
  - Cost: ~$3 per 1M input tokens

**API Calls:**
- All calls go through `lambda/shared/aws/bedrock.clj` wrapper
- Error handling and retry logic built-in
- Prompts defined inline in each function's `handler.clj`

### 5. Sync Layer

#### rclone Bidirectional Sync
- **Mode:** `bisync` (two-way sync)
- **Frequency:** Every 5 minutes
- **Conflict Resolution:** Newer file wins
- **Conflict Handling:** Older file renamed to `.conflict`
- **Platforms:**
  - macOS: launchd service
  - Linux: systemd timer
  - iOS: Obsidian + "Remotely Save" plugin

### 6. Observability

#### CloudWatch Logs
- Separate log group per Lambda function
- Retention: 30 days (configurable)
- Structured logging with context

#### CloudWatch Metrics
- Lambda invocations, errors, duration
- DynamoDB read/write capacity
- Step Functions executions
- Custom metrics for document processing

#### CloudWatch Alarms
- Lambda errors (threshold: 5 in 5 minutes)
- Lambda throttles (threshold: 1)
- DLQ messages (threshold: 0)
- Step Functions failures (threshold: 0)

#### CloudWatch Dashboard
- Real-time metrics visualization
- Lambda performance
- DynamoDB usage
- Cost tracking

#### Dead Letter Queue (SQS)
- Captures failed Lambda invocations
- Retention: 14 days
- Alarm triggers on any messages

## Data Flow

### Document Upload Flow

1. User creates/edits markdown file locally
2. rclone detects change and syncs to S3
3. S3 emits PUT event to EventBridge
4. EventBridge triggers 3 Lambda functions in parallel:
   - `classify-document`: Calls Bedrock, stores classification, invokes index update
   - `extract-entities`: Calls Bedrock, stores entities, creates entity pages
   - `extract-metadata`: Parses frontmatter/links, stores in DynamoDB
5. All results stored in DynamoDB
6. Agent outputs (entity pages, classification index) written to `_agent/` in S3
7. rclone syncs `_agent/` outputs back to local vault

**Total Latency:** < 10 seconds from upload to DynamoDB storage

### Daily Summary Flow

1. EventBridge triggers at 6 AM UTC daily
2. `generate-daily-summary` Lambda executes:
   - Queries DynamoDB for docs modified in last 24 hours
   - Retrieves full content from S3
   - Calls Bedrock Sonnet to generate summary
   - Writes summary to `_agent/summaries/YYYY-MM-DD.md`
3. rclone syncs summary to local vault

**Duration:** ~20-30 seconds

### Weekly Report Flow

1. EventBridge triggers Step Function at 8 PM UTC Sundays
2. Step Function invokes `generate-weekly-report` Lambda:
   - Queries DynamoDB for week's documents
   - Retrieves daily summaries from S3
   - Calls Bedrock Sonnet to generate report
   - Writes report to `_agent/reports/weekly/YYYY-Www.md`
3. Step Function marks execution as successful
4. rclone syncs report to local vault

**Duration:** ~60-90 seconds

## Security

### IAM Roles
- **Lambda Execution Role:**
  - S3: Read/Write to vault bucket
  - DynamoDB: Full access to metadata table
  - Bedrock: InvokeModel only
  - CloudWatch: Logs and metrics
  - X-Ray: Tracing (optional)

- **Step Functions Execution Role:**
  - Lambda: InvokeFunction
  - CloudWatch: Logs

### Encryption
- **S3:** Server-side encryption (SSE-S3)
- **DynamoDB:** Encryption at rest enabled
- **Lambda:** Environment variables encrypted with AWS managed keys

### Network
- All services within AWS VPC (optional)
- No public endpoints
- S3 bucket blocks all public access

## Cost Optimization

### Strategies
1. **Use on-demand DynamoDB:** Pay only for requests
2. **Lambda memory tuning:** Right-size for performance vs. cost
3. **Use Haiku for high-volume:** 10x cheaper than Sonnet
4. **S3 lifecycle policies:** Delete old versions after 90 days
5. **CloudWatch log retention:** 30 days vs. indefinite

### Cost Breakdown (100 docs/month)

| Service | Usage | Cost/Month |
|---------|-------|------------|
| S3 | 1 GB storage, 500 requests | $0.50 |
| DynamoDB | 10K reads, 5K writes | $1.50 |
| Lambda | 1K invocations, 128 MB-minutes | $3.00 |
| Bedrock (Haiku) | 100K tokens | $0.50 |
| Bedrock (Sonnet) | 50K tokens | $5.00 |
| CloudWatch | Logs, metrics, dashboard | $2.00 |
| EventBridge | 1K events | $0.10 |
| Step Functions | 30 executions | $0.05 |
| **Total** | | **~$12.65** |

## Scalability

### Current Limits
- Lambda concurrency: 1000 (default account limit)
- DynamoDB: Unlimited (on-demand)
- S3: Unlimited
- Bedrock: Model-specific rate limits

### Scaling Considerations
- For 1000+ docs/month: Consider reserved DynamoDB capacity
- For 10K+ docs/month: Implement Lambda batch processing
- For multiple vaults: Deploy separate stacks per vault

## Reliability

### Fault Tolerance
- Idempotent Lambda functions (safe to retry)
- Dead Letter Queue for failed invocations
- S3 versioning for data protection
- DynamoDB point-in-time recovery

### Monitoring
- CloudWatch alarms for all failure modes
- Automatic retry for transient errors
- DLQ for manual investigation

## Future Enhancements

1. **Semantic Search:** Add OpenSearch for full-text search
2. **Real-time Notifications:** SNS/email for summaries
3. **Custom Workflows:** User-defined processing rules
4. **Knowledge Graph:** Visualization of entity relationships
5. **Multi-user Support:** Separate vaults per user
