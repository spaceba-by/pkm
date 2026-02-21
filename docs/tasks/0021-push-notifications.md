# Task 0021: Push Notifications

**Status**: Planned

## Specifications

Add push notification support to deliver alerts to iOS users when significant events occur — new daily summaries, weekly reports, and persistent search updates exceeding the novelty threshold. The persistent search system already creates notification event records in DynamoDB (`notification#pending#<timestamp>#<id>` sort key pattern); this task builds the delivery infrastructure to send those notifications to iOS devices via Apple Push Notification service (APNs).

### Current Notification Events

The `persistent_search_summarize` Lambda already stores notification records in DynamoDB when a search monitor's novelty score exceeds the threshold:

```
PK: "user#{user-sub}"
SK: "notification#pending#{timestamp}#{notification-id}"
Attributes: notification_id, notification_type ("search_monitor"), monitor_id,
            monitor_name, novelty_score, timestamp, read (false)
```

This task extends the notification system to:
1. Track iOS device tokens for push delivery
2. Create notification records for daily summaries and weekly reports
3. Dispatch pending notifications via APNs
4. Provide an API for the iOS app to register device tokens and list/acknowledge notifications

### Architecture

```
Event Source (Lambda)
    ↓ writes notification record to DynamoDB
DynamoDB Stream
    ↓ triggers
notification_dispatch Lambda
    ↓ reads device tokens for user
    ↓ sends via SNS Platform Application (APNs)
iOS Device
    ↓ receives push notification
    ↓ user taps → deep links to relevant content
```

### DynamoDB Key Design (extending existing table)

**Device Token Records:**
```
PK: "user#{user-sub}"
SK: "device_token#{device-id}"
Attributes: device_token, platform ("ios"), app_version, registered_at, last_seen
```

**Notification Records** (existing pattern, extended with new types):
```
PK: "user#{user-sub}"
SK: "notification#pending#{timestamp}#{notification-id}"
Attributes:
  notification_id: UUID
  notification_type: "search_monitor" | "daily_summary" | "weekly_report"
  title: String
  body: String (preview text)
  deep_link: String (e.g., "/summaries/2024-02-21", "/searches/monitor-id")
  timestamp: ISO-8601
  read: Boolean
  delivered: Boolean
```

### API Endpoints (new)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | /devices | Register device token for push notifications |
| DELETE | /devices/{device-id} | Unregister device |
| GET | /notifications | List pending notifications for user |
| PUT | /notifications/{id}/read | Mark notification as read |

### APNs Integration

- Use AWS SNS Platform Application for APNs integration
- APNs auth key (P8 file) stored in Secrets Manager (`${project_name}/apns-auth-key`)
- SNS handles token management, retry, and delivery tracking
- Notification payload includes category, deep link, and badge count

### Notification Triggers

Extend these existing Lambdas to write notification records:
1. `generate_daily_summary` — write notification when summary is generated
2. `generate_weekly_report` — write notification when report is generated
3. `persistent_search_summarize` — already writes notifications (no change needed)

## Relevant Files

### New Lambda Functions
- `lambda/functions/notification_dispatch/handler.clj` — DynamoDB Stream trigger, sends via SNS/APNs
- `lambda/functions/api_device_tokens/handler.clj` — Device token registration API
- `lambda/functions/api_notifications/handler.clj` — List/acknowledge notifications API

### New Tests
- `lambda/tests/notifications/dispatch_test.clj` — Dispatch Lambda tests
- `lambda/tests/notifications/api_test.clj` — API handler tests

### Terraform (new/modified)
- `terraform/notifications.tf` — SNS Platform Application, Lambda functions, DynamoDB Stream, API routes
- `terraform/secrets.tf` — APNs auth key secret (placeholder from Task 0020)
- `terraform/eventbridge.tf` — No changes (existing Lambdas write records directly)

### iOS (new/modified)
- `ios/PKMReader/Core/Notifications/NotificationService.swift` — APNs registration, token management
- `ios/PKMReader/Core/Notifications/NotificationHandler.swift` — Handle received notifications, deep linking
- `ios/PKMReader/Core/Networking/APIClientProtocol.swift` — Add device token and notification methods
- `ios/PKMReader/Core/Networking/APIClient.swift` — Implement notification API calls
- `ios/project.yml` — Add Push Notifications capability and entitlement

### Modified Lambda Functions
- `lambda/functions/generate_daily_summary/handler.clj` — Add notification record creation
- `lambda/functions/generate_weekly_report/handler.clj` — Add notification record creation

## Acceptance Criteria

- [ ] iOS app registers for push notifications and sends device token to backend
- [ ] Device tokens stored in DynamoDB with user association
- [ ] SNS Platform Application configured for APNs (sandbox and production)
- [ ] APNs auth key stored securely in Secrets Manager
- [ ] Daily summary generation creates notification records
- [ ] Weekly report generation creates notification records
- [ ] Persistent search notifications continue to work (no regression)
- [ ] DynamoDB Stream triggers notification dispatch Lambda
- [ ] Dispatch Lambda sends push notifications via SNS to registered devices
- [ ] Notifications include deep link for navigation to relevant content
- [ ] API endpoint lists pending notifications for authenticated user
- [ ] API endpoint marks notifications as read
- [ ] iOS app handles notification taps and navigates to content
- [ ] Badge count reflects unread notification count
- [ ] Unit tests cover dispatch, API handlers, and notification record creation
- [ ] All existing tests continue to pass

## Implementation Steps

- [ ] Step 1: Add Push Notifications capability to `ios/project.yml` and create entitlements file
- [ ] Step 2: Create NotificationService for APNs registration and device token management
- [ ] Step 3: Add device token API endpoints (POST /devices, DELETE /devices/{device-id})
- [ ] Step 4: Create device token API Lambda handler
- [ ] Step 5: Create notification dispatch Lambda triggered by DynamoDB Stream on notification records
- [ ] Step 6: Configure SNS Platform Application for APNs in Terraform
- [ ] Step 7: Add notification record creation to `generate_daily_summary` and `generate_weekly_report`
- [ ] Step 8: Create notifications API Lambda (GET /notifications, PUT /notifications/{id}/read)
- [ ] Step 9: Add API Gateway routes for device and notification endpoints
- [ ] Step 10: Implement iOS notification handling and deep linking
- [ ] Step 11: Add badge count management
- [ ] Step 12: Write unit tests for all new Lambda handlers
- [ ] Step 13: Update UITestAPIClient and MockAPIClient with notification fixtures
- [ ] Step 14: Verify all existing tests pass
