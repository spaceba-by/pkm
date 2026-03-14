# Task 0022: Webhook Receiving & Classification

**Status**: Complete

## Specifications

Add an API endpoint for receiving external webhooks from third-party services (GitHub, email forwarding services, custom integrations). Inbound webhook payloads are validated, classified by source and content type, and routed into the PKM processing pipeline — either stored as documents in S3 (triggering the existing extract/classify/entity flow) or recorded directly in DynamoDB as structured events.

### Design Overview

Webhooks provide a way to ingest external information into the PKM system without manual document creation. Each webhook source is registered with a signing secret for payload verification. The system classifies the webhook content and decides how to process it.

**Webhook Flow:**
```
External Service → POST /webhooks/{source-id}
    ↓
webhook_receive Lambda
    ↓ validates signature using source-specific signing secret
    ↓ classifies payload (GitHub event, email, custom)
    ↓ routes to handler
    ├─→ Document route: writes markdown to S3 _agent/webhooks/ (no EventBridge trigger)
    └─→ Event route: stores structured event in DynamoDB
```

### DynamoDB Key Design (extending existing table)

**Webhook Source Configuration:**
```
PK: "webhook_source"
SK: "source#{source-id}"
Attributes: source_id, name, source_type ("github" | "email" | "custom"),
            signing_secret_arn, document_prefix (S3 path prefix),
            classification_hint, active, created, modified
```

**Webhook Event Records:**
```
PK: "webhook_event"
SK: "event#{timestamp}#{event-id}"
Attributes: event_id, source_id, source_type, event_type,
            payload_summary, document_path (if routed to S3),
            processed, timestamp
```

### API Endpoints

| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| POST | /webhooks/{source-id} | Signature verification (no JWT) | Receive webhook payload |
| POST | /admin/webhook-sources | JWT (admin) | Register webhook source |
| GET | /admin/webhook-sources | JWT (admin) | List webhook sources |
| PUT | /admin/webhook-sources/{id} | JWT (admin) | Update webhook source |
| DELETE | /admin/webhook-sources/{id} | JWT (admin) | Delete webhook source |
| GET | /admin/webhook-events | JWT (admin) | List recent webhook events |

### Webhook Signature Verification

Each webhook source has a signing secret stored in Secrets Manager. Verification follows standard patterns:
- **GitHub**: HMAC-SHA256 of payload body, compared against `X-Hub-Signature-256` header
- **Custom**: HMAC-SHA256 with configurable header name
- **Email forwarding**: Source IP allowlisting or API key in header

### Document Generation

When a webhook is classified for document storage, the Lambda generates a markdown file:
```markdown
---
source: github
event_type: issue_opened
webhook_id: abc-123
received_at: 2024-02-21T10:30:00Z
---

# Issue: Bug in login flow

Repository: user/repo
Author: username
...
```

The file is written to `S3://{vault-bucket}/_agent/webhooks/{source-id}/{date}/{event-id}.md`. The `_agent/` prefix means these documents do NOT trigger the EventBridge processing pipeline — the `webhook_receive` handler is self-contained.

### Source-Specific Classifiers

Classifiers are implemented as `case` dispatch on `source_type`:
- `github`: Parses event type from `X-GitHub-Event` header, extracts issue/PR/commit details
- `email`: Parses email headers, extracts subject/body/sender
- `custom`: Passes payload through with minimal transformation

## Relevant Files

### New Lambda Functions
- `lambda/functions/webhook_receive/handler.clj` — Receive and validate webhook payloads
- `lambda/functions/api_webhook_sources/handler.clj` — Admin CRUD for webhook source configuration
- `lambda/functions/api_webhook_events/handler.clj` — List webhook events
- `lambda/shared/webhooks/utils.clj` — HMAC verification, classifiers, key helpers, formatters

### New Tests
- `lambda/tests/webhooks/utils_test.clj` — HMAC, classification, formatting tests

### Terraform (new)
- `terraform/webhooks.tf` — Lambda functions, API Gateway routes, CloudWatch logs, permissions

### Modified Files
- `lambda/build.clj` — Add new function targets
- `lambda/bb.edn` — Add new paths to classpath

## Acceptance Criteria

- [x] Webhook source registration via admin API with signing secret in Secrets Manager
- [x] Webhook receive endpoint validates payload signature before processing
- [x] Invalid signatures return 401 with no processing
- [x] GitHub webhook events are parsed and classified by event type
- [x] Document-routed webhooks generate markdown files in S3 `_agent/webhooks/` with correct frontmatter
- [x] Event-routed webhooks store structured records in DynamoDB
- [x] Admin API supports CRUD for webhook sources (admin group required)
- [x] Admin API lists recent webhook events with filtering
- [x] Webhook endpoint is publicly accessible (no JWT) but signature-protected
- [x] Unit tests cover signature verification, classification, and routing
- [x] All existing tests continue to pass (128 tests, 793 assertions)

## Implementation Steps

- [x] Step 1: Create shared utilities (`shared/webhooks/utils.clj`) — key helpers, HMAC verification, classifiers, document generation, formatters
- [x] Step 2: Create `webhook_receive` Lambda handler with signature validation and routing
- [x] Step 3: Create admin API Lambda for webhook source CRUD (`api_webhook_sources`)
- [x] Step 4: Create webhook events listing API (`api_webhook_events`)
- [x] Step 5: Update `build.clj` and `bb.edn` with new function targets
- [x] Step 6: Add Terraform infrastructure (`webhooks.tf` — Lambdas, API routes, CloudWatch logs, permissions)
- [x] Step 7: Write unit tests (`tests/webhooks/utils_test.clj`) and update test runner
- [x] Step 8: Verify all tests pass (128 tests, 793 assertions, 0 failures)
