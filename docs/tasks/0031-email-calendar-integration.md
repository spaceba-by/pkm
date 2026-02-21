# Task 0031: Email/Calendar Integration

**Status**: Planned

## Specifications

Ingest emails and calendar events as contextual data in the PKM system. Connect to email and calendar providers via OAuth, periodically fetch new items, and process them through the existing classification and entity extraction pipeline. This enriches the knowledge base with communication and scheduling context alongside document content.

### Key Capabilities

- OAuth-based connection to email providers (Gmail, Outlook) and calendar providers (Google Calendar, Outlook Calendar)
- Periodic sync of new emails and calendar events
- Email processing: extract subject, sender, recipients, body; classify and extract entities
- Calendar processing: extract event title, attendees, description, time; link to related documents
- Generated markdown documents stored in S3 under `_agent/email/` and `_agent/calendar/` prefixes
- User-configurable filters (folders, labels, date ranges)

### Architecture

- OAuth credentials stored in Secrets Manager (depends on Task 0020)
- Scheduled Lambda fetches new items from provider APIs
- Items converted to markdown documents and written to S3
- Existing EventBridge pipeline processes them (extract_metadata, classify, extract_entities)

**Depends on:** Task 0020 (Secrets Management) for OAuth credential storage.

## Relevant Files

### New Lambda Functions
- `lambda/functions/email_sync/handler.clj` — Fetch and process emails
- `lambda/functions/calendar_sync/handler.clj` — Fetch and process calendar events
- `lambda/functions/api_integrations/handler.clj` — Integration management API (connect/disconnect, configure)

### New Shared Libraries
- `lambda/shared/integrations/oauth.clj` — OAuth flow handling
- `lambda/shared/integrations/email.clj` — Email provider client
- `lambda/shared/integrations/calendar.clj` — Calendar provider client

### Terraform
- `terraform/integrations.tf` — Lambda functions, EventBridge schedules, secrets

### iOS
- `ios/PKMReader/Features/Settings/IntegrationSettingsView.swift` — Connect/disconnect providers

## Acceptance Criteria

- [ ] OAuth flow for connecting email and calendar providers
- [ ] Periodic sync of new emails and calendar events
- [ ] Items converted to markdown and processed through existing pipeline
- [ ] User-configurable filters for email folders and calendar types
- [ ] Integration management in iOS settings
- [ ] OAuth credentials securely stored in Secrets Manager
- [ ] Unit tests for sync and conversion logic
- [ ] All existing tests continue to pass

## Implementation Steps

- [ ] Step 1: Create OAuth flow handling with provider-specific implementations
- [ ] Step 2: Create email sync Lambda with provider client
- [ ] Step 3: Create calendar sync Lambda with provider client
- [ ] Step 4: Add markdown generation for emails and calendar events
- [ ] Step 5: Create integration management API
- [ ] Step 6: Add Terraform infrastructure and EventBridge schedules
- [ ] Step 7: Create iOS integration settings view
- [ ] Step 8: Write unit tests
