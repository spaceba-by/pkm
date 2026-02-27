# PKM Agent System Architecture

## Overview

The PKM Agent System is a serverless AWS architecture that automatically processes Personal Knowledge Management (PKM) markdown files, providing classification, entity extraction, and intelligent summarization.

## Architecture Diagram

```
┌─────────────────┐                    ┌─────────────────┐
│  Local Vault    │                    │    iOS App      │
│   (macOS)       │                    │   (SwiftUI)     │
└────────┬────────┘                    └────────┬────────┘
         │ rclone bisync (every 5 min)          │ HTTPS
         ▼                                       ▼
┌──────────────────────────────────────────────────────────────┐
│                         AWS Cloud                             │
│                                                               │
│  ┌──────────────┐              ┌──────────────────────────┐  │
│  │  S3 Bucket   │              │     Amazon Cognito       │  │
│  │  (Source of  │              │  • User Pool (email)     │  │
│  │   Truth)     │              │  • iOS App Client        │  │
│  └──────┬───────┘              │  • Identity Pool         │  │
│         │ S3 Events            └────────────┬─────────────┘  │
│         ▼                                    │ JWT Auth       │
│  ┌─────────────────────┐                    ▼                │
│  │   EventBridge       │       ┌──────────────────────────┐  │
│  │  • markdown-events  │       │    API Gateway (HTTP)    │  │
│  │  • daily-schedule   │       │  • JWT Authorizer        │  │
│  │  • weekly-schedule  │       │  • CORS enabled          │  │
│  └───┬─────────────────┘       │  • 25 REST endpoints     │  │
│      │                          └────────────┬─────────────┘  │
│      ▼                                       │                │
│  ┌────────────────────┐       ┌──────────────▼─────────────┐ │
│  │ Processing Lambdas │       │      API Lambdas           │ │
│  │ • classify-doc     │       │ • api-list-documents       │ │
│  │ • extract-entity   │       │ • api-get-document         │ │
│  │ • extract-metadata │       │ • api-search               │ │
│  │ • daily-summary    │       │ • api-list-tags            │ │
│  │ • weekly-report    │       │ • api-documents-by-tag     │ │
│  │ • update-index     │       │ • api-list-classifications │ │
│  │ • bulk-reclassify  │       │ • api-list-summaries       │ │
│  │ • delete-document  │       │ • api-list-reports         │ │
│  │ • index-embeddings │       │ • api-update-classification│ │
│  │ • persistent-search│       │ • api-bulk-reclassify      │ │
│  │ • notif-dispatch   │       │ • api-create/update/delete │ │
│  └─────────┬──────────┘       │ • api-graph-data           │ │
│            │                   │ • api-search-monitors      │ │
│            │                   │ • api-device-tokens        │ │
│            │                   │ • api-notifications        │ │
│            │                   └──────────────┬─────────────┘ │
│            │                                  │                │
│            ▼                                  ▼                │
│  ┌──────────────────────────────────────────────────────────┐│
│  │                    DynamoDB Table                         ││
│  │  PK: doc#path | tag#name | entity#type#name               ││
│  │  SK: metadata | doc#path | mention#doc                    ││
│  │  GSI: tag-index, classification-index, entity-index       ││
│  └──────────────────────────────────────────────────────────┘│
│                                                               │
│  ┌──────────────────────────────────────────────────────────┐│
│  │         Amazon Bedrock                                    ││
│  │  • Claude Haiku 4.5 (classify, extract)                   ││
│  │  • Claude Sonnet 4.5 (summaries, reports)                ││
│  └──────────────────────────────────────────────────────────┘│
│                                                               │
└───────────────────────────────────────────────────────────────┘
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

**Processing Functions (11):**

| Function | Runtime | Memory | Timeout | Trigger | Purpose |
|----------|---------|--------|---------|---------|---------|
| `classify-document` | Babashka | 512 MB | 30s | S3 PUT | Classify doc type using Bedrock |
| `extract-entities` | Babashka | 512 MB | 30s | S3 PUT | Extract named entities |
| `extract-metadata` | Babashka | 256 MB | 10s | S3 PUT | Parse frontmatter, links, tags |
| `generate-daily-summary` | Babashka | 1024 MB | 60s | Cron (6 AM) | Generate daily summary |
| `generate-weekly-report` | Babashka | 2048 MB | 120s | Step Function | Generate weekly report |
| `update-classification-index` | Babashka | 256 MB | 30s | Scheduled (every 6 hours) | Update classification index |
| `bulk-reclassify` | Babashka | 512 MB | 300s | API invoke | Bulk reclassification with dry-run |
| `delete-document` | Babashka | 256 MB | 10s | S3 DELETE | Cascade-delete DynamoDB records |
| `persistent-search-execute` | Babashka | 512 MB | 60s | Scheduled | Execute search monitors via Brave API |
| `persistent-search-summarize` | Babashka | 1024 MB | 60s | Invoke | Summarize search results with AI |
| `notification-dispatch` | Babashka | 256 MB | 30s | DynamoDB Stream | Dispatch push notifications via SNS/APNs |

**CLI Utilities** (run locally, not deployed as Lambda):

| Script | Purpose |
|--------|---------|
| `index-embeddings` | Generate vector embeddings for semantic search index |

**API Functions (19):**

| Function | Runtime | Memory | Timeout | Endpoint | Purpose |
|----------|---------|--------|---------|----------|---------|
| `api-list-documents` | Babashka | 256 MB | 10s | GET /documents | List documents with filters |
| `api-get-document` | Babashka | 256 MB | 10s | GET /documents/{key+} | Get document with content |
| `api-search` | Babashka | 256 MB | 10s | GET /search | Search by title/path/tags/semantic |
| `api-list-tags` | Babashka | 256 MB | 10s | GET /tags | List all tags with counts |
| `api-documents-by-tag` | Babashka | 256 MB | 10s | GET /tags/{tag}/documents | Get docs by tag |
| `api-list-classifications` | Babashka | 256 MB | 10s | GET /classifications | List classification counts |
| `api-list-summaries` | Babashka | 256 MB | 10s | GET /summaries | List daily summaries |
| `api-list-reports` | Babashka | 256 MB | 10s | GET /reports | List weekly reports |
| `api-update-classification` | Babashka | 256 MB | 10s | PUT /documents/classification/{key+} | Update classification |
| `api-bulk-reclassify` | Babashka | 256 MB | 10s | POST /admin/reclassify | Trigger bulk reclassification |
| `api-create-document` | Babashka | 256 MB | 10s | POST /documents | Create document (admin) |
| `api-update-document` | Babashka | 256 MB | 10s | PUT /documents/{key+} | Update document (admin) |
| `api-delete-document` | Babashka | 256 MB | 10s | DELETE /documents/{key+} | Delete document (admin) |
| `api-graph-data` | Babashka | 256 MB | 10s | GET /graph | Entity relationship graph |
| `api-search-monitors` | Babashka | 256 MB | 10s | GET /searches | List search monitors |
| `api-search-monitor-detail` | Babashka | 256 MB | 10s | GET /searches/{id} | Search monitor detail |
| `api-search-summaries` | Babashka | 256 MB | 10s | GET /searches/{id}/summaries | List search summaries |
| `api-device-tokens` | Babashka | 256 MB | 10s | POST /devices | Register/unregister device tokens |
| `api-notifications` | Babashka | 256 MB | 10s | GET /notifications | List and acknowledge notifications |

**Shared Code:**
- AWS wrappers in `lambda/shared/aws/`: `bedrock.clj`, `dynamodb.clj`, `s3.clj`, `sns.clj`, `lambda.clj`, `secrets_manager.clj`, `brave_search.clj`
- API utilities in `lambda/shared/api/`: `response.clj`
- Markdown parsing in `lambda/shared/markdown/`: `utils.clj`
- Notification utilities in `lambda/shared/notifications/`: `utils.clj`
- Vector search in `lambda/shared/search/`: `chunker.clj`, `embeddings.clj`, `indexer.clj`, `semantic.clj`, `vector_index.clj`
- Bundled into each Lambda's uberjar via `build.clj`
- Uses `bblf` (Babashka Lambda Framework) for runtime

#### Step Functions
- **weekly-report-workflow:**
  1. Invokes `generate-weekly-report` Lambda
  2. Checks for success
  3. Handles errors with retry logic

### 3. Mobile API Layer

#### Amazon Cognito
- **User Pool:** Email-based authentication with MFA optional
- **App Client:** iOS client (no secret, SRP auth flow)
- **Identity Pool:** Federated identities for AWS resource access
- **Features:**
  - Email verification required
  - Strong password policy (8+ chars, mixed case, numbers, symbols)
  - Account recovery via email

#### API Gateway (HTTP API)
- **Type:** HTTP API (v2) - lower latency, lower cost than REST API
- **Authentication:** JWT Authorizer with Cognito User Pool
- **CORS:** Enabled for iOS app
- **Throttling:** 100 burst, 50 requests/second
- **Endpoints:**
  ```
  GET    /documents                            - List with optional classification filter
  GET    /documents/{key+}                     - Get document with content
  POST   /documents                            - Create document (admin)
  PUT    /documents/{key+}                     - Update document (admin)
  DELETE /documents/{key+}                     - Delete document (admin)
  GET    /search?q=...                         - Search documents (keyword/semantic)
  GET    /tags                                 - List all tags
  GET    /tags/{tag}/documents                 - Get documents by tag
  GET    /classifications                      - List classification types
  GET    /summaries                            - List daily summaries
  GET    /reports                              - List weekly reports
  PUT    /documents/classification/{key+}      - Update classification
  POST   /admin/reclassify                     - Trigger bulk reclassification
  GET    /graph                                - Entity relationship graph data
  POST   /searches                             - Create search monitor
  GET    /searches                             - List search monitors
  GET    /searches/{id}                        - Search monitor detail
  PUT    /searches/{id}                        - Update search monitor
  DELETE /searches/{id}                        - Delete search monitor
  GET    /searches/{id}/summaries              - List search summaries
  GET    /searches/{id}/summaries/{timestamp}  - Search summary detail
  POST   /devices                              - Register device for push notifications
  DELETE /devices/{device-id}                  - Unregister device
  GET    /notifications                        - List pending notifications
  PUT    /notifications/{id}/read              - Mark notification as read
  ```

### 4. Event-Driven Processing

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

4. **classification-index-schedule:**
   - Schedule: `rate(6 hours)`
   - Target: `update-classification-index` Lambda
   - Purpose: Rebuild classification index periodically

### 5. AI/ML Layer

#### Amazon Bedrock

**Models:**
- **Claude Haiku 4.5:** High-volume, low-cost operations
  - Document classification
  - Entity extraction
  - Cost: ~$0.25 per 1M input tokens

- **Claude Sonnet 4.5:** Quality-critical operations
  - Daily summaries
  - Weekly reports
  - Cost: ~$3 per 1M input tokens

**API Calls:**
- All calls go through `lambda/shared/aws/bedrock.clj` wrapper
- Error handling and retry logic built-in
- Prompts defined inline in each function's `handler.clj`

### 6. Sync Layer

#### rclone Bidirectional Sync
- **Mode:** `bisync` (two-way sync)
- **Frequency:** Every 5 minutes
- **Conflict Resolution:** Newer file wins
- **Conflict Handling:** Older file renamed to `.conflict`
- **Platforms:**
  - macOS: launchd service
  - Linux: systemd timer
  - iOS: Obsidian + "Remotely Save" plugin

### 7. Observability

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

1. ~~**Semantic Search:** Add OpenSearch for full-text search~~ ✅ Implemented (Task 0009) — in-memory vector index with cosine similarity
2. ~~**Real-time Notifications:** SNS/email for summaries~~ ✅ Implemented (Task 0021) — push notifications via SNS/APNs for summaries, reports, and search monitors
3. **Custom Workflows:** User-defined processing rules
4. ~~**Knowledge Graph:** Visualization of entity relationships~~ ✅ Implemented (Task 0011) — interactive force-directed graph in iOS
5. **Multi-user Support:** Separate vaults per user
