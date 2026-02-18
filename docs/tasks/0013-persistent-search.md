# Task 0013: Persistent Search

**Status**: In Progress (pending integration test and merge)

## Specifications

Add a persistent search feature that allows users to define search monitors — named sets of search terms that are periodically executed against web search APIs. An AI agent (via Bedrock) summarizes each batch of search results and compares the new summary against the previous one to detect meaningful changes. A configurable novelty threshold determines whether the changes are significant enough to flag for the user, enabling future notification triggers (SNS, push notifications, etc.).

### Design Overview

**Search Monitors** are the core resource. Each monitor has:
- A user-defined name and description
- One or more search terms (queries)
- A schedule interval (e.g., every 6 hours, daily, weekly)
- A novelty threshold (0.0–1.0) controlling sensitivity to new information
- Status tracking (active/paused)

**Execution Flow:**
1. EventBridge scheduled rule triggers `persistent_search_execute` Lambda at a fixed interval (e.g., every 6 hours)
2. The execute Lambda queries DynamoDB for active monitors whose next execution time has passed
3. For each due monitor, it calls an external web search API (Brave Search) for each search term, collecting results
4. Raw search results are stored in DynamoDB as a bounded search snapshot (top 10 results per search term, essential fields only: title, URL, snippet, date). If payloads exceed DynamoDB's 400KB item limit, overflow is stored in S3 with a DynamoDB pointer.
5. The execute Lambda asynchronously invokes `persistent_search_summarize`
6. The summarize Lambda retrieves the latest snapshot and the previous summary for the monitor
7. Bedrock (Sonnet) generates a new summary from the search results and produces a novelty score by comparing against the previous summary
8. If the novelty score exceeds the monitor's threshold, the snapshot is flagged as having significant updates
9. The summary, novelty score, and flag are stored in DynamoDB
10. Flagged results are written to `_agent/searches/{monitor-id}/{date}.md` in S3 for vault sync (using monitor ID, not name, to avoid special character issues and orphaned objects on rename)

**DynamoDB Key Design** (extending the existing single-table):
- Search monitors: `PK = "user#<user-sub>"`, `SK = "search_monitor#<monitor-id>#CONFIG"`
- Search snapshots: `PK = "user#<user-sub>"`, `SK = "search_monitor#<monitor-id>#snapshot#<timestamp>"`
- Search summaries: `PK = "user#<user-sub>"`, `SK = "search_monitor#<monitor-id>#summary#<timestamp>"`
- Notification events: `PK = "user#<user-sub>"`, `SK = "notification#pending#<timestamp>#<notification-id>"`
- GSI: `search-schedule-index` on `monitor_status` (hash) + `next_execution` (range) for efficient polling of due monitors. Projects base table keys (`PK`, `SK`) so the execute Lambda can identify both user and monitor ID. Note: low-cardinality `monitor_status` partition key is acceptable at current expected scale (dozens to low hundreds of monitors); if hot partitions become an issue, shard the key (e.g., `active#<bucket>`)

This user-scoped key design enables efficient queries for:
- `GET /searches` — Query `PK = "user#<sub>"` with `begins_with(SK, "search_monitor#")` and `ends_with` filter on `#CONFIG`
- `GET /searches/{id}/summaries` — Query `PK = "user#<sub>"` with `begins_with(SK, "search_monitor#<id>#summary#")`
- Listing pending notifications — Query `PK = "user#<sub>"` with `begins_with(SK, "notification#pending#")`

**Web Search Provider:**
Brave Search API is the initial provider due to its generous free tier and simple REST API. The search client will be abstracted behind a provider interface to allow swapping providers in the future.

**Summarization Agent:**
Uses Bedrock Sonnet to:
1. Synthesize search results into a coherent summary organized by topic/theme
2. Compare the new summary against the previous summary to identify genuinely new information
3. Assign a novelty score (0.0 = no new information, 1.0 = entirely new information)
4. Produce a structured diff highlighting what is new, changed, or no longer appearing

**Notification Threshold:**
Each monitor has a configurable threshold (default 0.3). When the novelty score exceeds the threshold, the system:
- Flags the snapshot record in DynamoDB (`significant_update = true`)
- Writes a summary document to S3 `_agent/searches/` for vault sync
- Stores a notification event record (using the user-scoped key design above) for future consumption by push notification or SNS integration

### API Endpoints (new)
- `POST /searches` — Create a new search monitor
- `GET /searches` — List all search monitors for the user
- `GET /searches/{id}` — Get monitor details with recent summaries
- `PUT /searches/{id}` — Update monitor (terms, schedule, threshold, status)
- `DELETE /searches/{id}` — Delete a monitor and its history
- `GET /searches/{id}/summaries` — List summaries for a monitor
- `GET /searches/{id}/summaries/{timestamp}` — Get a specific summary with diff

## Relevant Files

### New Lambda Functions
- `lambda/functions/persistent_search_execute/handler.clj` — Scheduled execution of web searches
- `lambda/functions/persistent_search_summarize/handler.clj` — AI summarization and comparison agent
- `lambda/functions/api_search_monitors/handler.clj` — CRUD API for search monitors
- `lambda/functions/api_search_monitor_detail/handler.clj` — Get monitor with summaries
- `lambda/functions/api_search_summaries/handler.clj` — List/get summaries for a monitor

### New Shared Libraries
- `lambda/shared/aws/brave_search.clj` — Brave Search API client
- `lambda/shared/aws/secrets_manager.clj` — Secrets Manager client with in-memory caching
- `lambda/shared/search/provider.clj` — Search provider abstraction
- `lambda/shared/search/summarizer.clj` — Summarization and comparison logic

### Terraform (updated/created)
- `terraform/persistent_search_lambda.tf` — Lambda definitions + Secrets Manager resource for Brave API key
- `terraform/api_persistent_search.tf` — API Gateway routes for search monitor endpoints
- `terraform/eventbridge.tf` — Scheduled rule for search execution
- `terraform/dynamodb.tf` — GSI `search-schedule-index` (ALL projection)
- `terraform/variables.tf` — Brave Search API key variable, schedule interval
- `terraform/iam.tf` — Secrets Manager read policy for Lambda role

### Tests
- `lambda/tests/persistent_search/execute_test.clj` — Execute Lambda unit tests
- `lambda/tests/persistent_search/summarizer_test.clj` — Summarizer unit tests
- `lambda/tests/persistent_search/api_test.clj` — API handler unit tests

### Existing Files (to be updated)
- `lambda/build.clj` — Add new functions to build targets
- `docs/ROADMAP.md` — Add task reference

## Acceptance Criteria

- [x] Search monitors can be created, listed, updated, and deleted via API
- [x] Each monitor supports multiple search terms and a configurable schedule interval
- [x] Scheduled Lambda executes web searches for all due monitors
- [x] Search results are stored as snapshots in DynamoDB
- [x] AI agent summarizes search results using Bedrock Sonnet
- [x] Agent compares new summary against previous summary and produces a novelty score
- [x] Novelty score threshold is configurable per monitor (default 0.3)
- [x] Significant updates are flagged in DynamoDB and written to S3 `_agent/searches/{monitor-id}/`
- [x] Notification event records are created when threshold is exceeded
- [x] Search provider is abstracted to allow future provider changes
- [x] API endpoints are JWT-protected and scoped to the authenticated user
- [x] Unit tests cover execute, summarize, and API handlers
- [x] Monitors can be paused and resumed

## Implementation Steps

- [x] Step 1: Design DynamoDB key schema for monitors, snapshots, and summaries; add GSI to `terraform/dynamodb.tf`
- [x] Step 2: Create Brave Search API client (`lambda/shared/aws/brave_search.clj`) with provider abstraction
- [x] Step 3: Create `persistent_search_execute` Lambda — poll due monitors, execute searches, store snapshots
- [x] Step 4: Create summarization and comparison logic (`lambda/shared/search/summarizer.clj`) using Bedrock Sonnet
- [x] Step 5: Create `persistent_search_summarize` Lambda — generate summary, compute novelty score, flag significant updates, write to S3
- [x] Step 6: Add EventBridge scheduled rule for periodic execution in Terraform
- [x] Step 7: Create API Lambda handlers for search monitor CRUD (`api_search_monitors`, `api_search_monitor_detail`, `api_search_summaries`)
- [x] Step 8: Add API Gateway routes and Terraform configuration for new endpoints
- [x] Step 9: Add Secrets Manager resource for Brave Search API key; wire environment variables to Lambdas
      Secrets Manager secret created in `persistent_search_lambda.tf`; Lambda fetches API key at runtime via `aws.secrets-manager` client with in-memory caching.
- [x] Step 10: Update `lambda/build.clj` to include new function targets
- [x] Step 11: Write unit tests for execute, summarize, and API handlers
      60 tests, 487 assertions covering formatting, validation, key design, provider abstraction, and search execution logic.
- [ ] Step 12: Integration test — create monitor, trigger execution, verify summary and threshold flagging
      Requires deployment to AWS and a live Brave Search API key.

## Summary of Changes

### Lambda Functions (5 new)
- `persistent_search_execute` — EventBridge-triggered, polls GSI for due monitors, executes Brave Search, stores snapshots, invokes summarizer async
- `persistent_search_summarize` — Generates Bedrock Sonnet summary, computes novelty score, flags significant updates, writes reports to S3
- `api_search_monitors` — CRUD (POST/GET/PUT/DELETE) for search monitors
- `api_search_monitor_detail` — GET monitor details with recent summaries (newest first)
- `api_search_summaries` — GET summaries list and individual summary by timestamp

### Shared Libraries (4 new)
- `aws/brave_search.clj` — Brave Search API client implementing `SearchProvider` protocol
- `aws/secrets_manager.clj` — Secrets Manager client with in-memory caching for Lambda container reuse
- `search/provider.clj` — `SearchProvider` protocol abstraction for swappable search backends
- `search/summarizer.clj` — Bedrock-powered summarization, comparison, and novelty scoring

### Infrastructure
- DynamoDB GSI `search-schedule-index` with ALL projection for efficient monitor polling
- Secrets Manager secret for Brave Search API key (not stored in Terraform state)
- EventBridge schedule (every 6 hours) triggering execute Lambda
- API Gateway routes: `/searches`, `/searches/{id}`, `/searches/{id}/summaries`, `/searches/{id}/summaries/{timestamp}`
- IAM policies for Secrets Manager read access and Lambda invocation

### Review Fixes (Copilot feedback)
- GSI projection changed from KEYS_ONLY to ALL (eliminates N+1 reads)
- Brave API key moved from TF env var to Secrets Manager
- Monitor detail returns summaries newest-first via `scan-index-forward false`
- Blank name validation added to monitor update
- Nil/incomplete items filtered from GSI results
- Execute handler short-circuits when API key is not configured
- Redundant `query-all` replaced with single descending query in summarizer
