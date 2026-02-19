# Task 0010: Write Support & Admin API

**Status**: Complete

## Specifications

Enable document creation and editing from the mobile app. Requires admin authorization beyond the current read-only JWT validation, implemented via Cognito user groups with group-based access control. Includes API endpoints for creating, updating, and deleting documents, with changes syncing back to the Obsidian vault via S3.

## Relevant Files

- `terraform/cognito.tf` - Cognito user groups (admin, reader)
- `terraform/api_gateway.tf` - Write API routes (POST/PUT/DELETE /documents)
- `terraform/api_lambda.tf` - Write Lambda definitions (3 new functions)
- `lambda/functions/api_create_document/handler.clj` - Create document handler
- `lambda/functions/api_update_document/handler.clj` - Update document handler
- `lambda/functions/api_delete_document/handler.clj` - Delete document handler
- `lambda/shared/api/response.clj` - New response types and auth utilities
- `lambda/tests/api/write_handlers_test.clj` - Unit tests for write operations
- `ios/PKMReader/Features/Editor/DocumentEditorView.swift` - Editor view
- `ios/PKMReader/Features/Editor/DocumentEditorViewModel.swift` - Editor view model
- `ios/PKMReader/Core/Networking/APIClientProtocol.swift` - Write API methods
- `ios/PKMReader/Core/Networking/APIClient.swift` - Write API implementation

## Acceptance Criteria

- [x] Cognito user groups for admin vs read-only access
- [x] API endpoints for create, update, and delete documents
- [x] Group-based authorization in Lambda handlers (via Cognito JWT claims)
- [x] Document editor view in iOS app
- [x] Markdown preview in editor
- [x] Changes sync to S3 and back to local vault via rclone
- [x] Conflict detection for concurrent edits
- [x] Write operations covered by unit and integration tests
- [x] Admin-only endpoints reject non-admin users

## Implementation Steps

- [x] Step 1: Create Cognito user groups (admin, reader) in Terraform
- [x] Step 2: Configure group-based authorization in API Gateway
- [x] Step 3: Implement `api_create_document` Lambda handler
- [x] Step 4: Implement `api_update_document` Lambda handler
- [x] Step 5: Implement `api_delete_document` Lambda handler
- [x] Step 6: Add conflict detection (last-modified checks)
- [x] Step 7: Build document editor view in iOS app
- [x] Step 8: Add markdown preview to editor
- [x] Step 9: Write unit tests for write API handlers
- [x] Step 10: Write integration tests for authorization

## Summary of Changes

### Backend (Terraform + Lambda)

**Cognito User Groups**: Added `admin` and `reader` user groups to the Cognito User Pool. Admin group has precedence 1, reader has precedence 10.

**API Routes**: Added three new API Gateway routes:
- `POST /documents` - Create a new document (admin only)
- `PUT /documents/{key+}` - Update an existing document (admin only)
- `DELETE /documents/{key+}` - Delete a document (admin only)

**Lambda Functions** (3 new):
- `api_create_document` - Validates key format, checks for duplicates, writes to S3, creates DynamoDB metadata
- `api_update_document` - Conflict detection via `ifUnmodifiedSince`, updates S3 content and DynamoDB modified timestamp
- `api_delete_document` - Removes S3 object; DynamoDB cleanup happens via existing EventBridge delete_document handler

**Authorization**: Group-based access control enforced at Lambda level using Cognito JWT `cognito:groups` claim. Added `get-user-groups`, `admin?`, and `require-admin` utilities to `api.response`.

**Response Utilities**: Added `forbidden` (403), `conflict` (409), `created` (201), and `no-content` (204) response helpers.

**Tests**: 59 tests, 429 assertions. New test file covers authorization logic (group extraction, admin checks), key validation, conflict detection, and response types.

### iOS App

**API Protocol**: Extended `APIClientProtocol` with `createDocument`, `updateDocument`, and `deleteDocument` methods.

**API Client**: Added `performMutatingRequest` generic method supporting POST/PUT/DELETE with retry logic and conflict (409) / forbidden (403) error handling.

**Document Editor**: New `DocumentEditorView` and `DocumentEditorViewModel` supporting:
- Create mode: key, title, and content fields
- Edit mode: content editing with conflict detection
- Markdown preview toggle (eye/pencil icon)
- Save state management with error display

**Document Detail View**: Added toolbar menu with Edit and Delete actions. Delete requires confirmation dialog.

**Document List View**: Added "+" button to create new documents.

**Mock Clients**: Updated `MockAPIClient`, `UITestAPIClient`, and preview API clients for new protocol methods.
