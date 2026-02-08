# Task 0010: Write Support & Admin API

**Status**: Planned

## Specifications

Enable document creation and editing from the mobile app. Requires admin authorization beyond the current read-only JWT validation, implemented via Cognito user groups with group-based access control. Includes API endpoints for creating, updating, and deleting documents, with changes syncing back to the Obsidian vault via S3.

## Relevant Files

- `terraform/cognito.tf` - Cognito user groups (to be updated)
- `terraform/api_gateway.tf` - Write API routes (to be updated)
- `terraform/api_lambda.tf` - Write Lambda definitions (to be updated)
- `lambda/functions/` - Write API handlers (to be created)
- `ios/PKMReader/` - Editor views (to be created)
- `docs/ISSUES.md` - Documents the admin authorization requirement

## Acceptance Criteria

- [ ] Cognito user groups for admin vs read-only access
- [ ] API endpoints for create, update, and delete documents
- [ ] Group-based authorization in API Gateway
- [ ] Document editor view in iOS app
- [ ] Markdown preview in editor
- [ ] Changes sync to S3 and back to local vault via rclone
- [ ] Conflict detection for concurrent edits
- [ ] Write operations covered by unit and integration tests
- [ ] Admin-only endpoints reject non-admin users

## Implementation Steps

- [ ] Step 1: Create Cognito user groups (admin, reader) in Terraform
- [ ] Step 2: Configure group-based authorization in API Gateway
- [ ] Step 3: Implement `api_create_document` Lambda handler
- [ ] Step 4: Implement `api_update_document` Lambda handler
- [ ] Step 5: Implement `api_delete_document` Lambda handler
- [ ] Step 6: Add conflict detection (last-modified checks)
- [ ] Step 7: Build document editor view in iOS app
- [ ] Step 8: Add markdown preview to editor
- [ ] Step 9: Write unit tests for write API handlers
- [ ] Step 10: Write integration tests for authorization
