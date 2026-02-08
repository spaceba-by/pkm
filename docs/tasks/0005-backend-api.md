# Task 0005: Backend API Infrastructure

**Status**: Complete

## Specifications

iOS Phase 1: Build the backend API infrastructure for the iOS app. Includes Cognito user authentication, API Gateway HTTP API with JWT authorization, 8 API Lambda functions for document access, and integration test scripts.

## Relevant Files

- `terraform/cognito.tf` - Cognito User Pool and Identity Pool
- `terraform/api_gateway.tf` - HTTP API Gateway with JWT authorizer
- `terraform/api_lambda.tf` - API Lambda function definitions
- `lambda/functions/api_list_documents/handler.clj` - List documents with classification filter
- `lambda/functions/api_get_document/handler.clj` - Get document with content
- `lambda/functions/api_search/handler.clj` - Search by title, path, tags
- `lambda/functions/api_list_tags/handler.clj` - List all tags with counts
- `lambda/functions/api_documents_by_tag/handler.clj` - Get documents by tag
- `lambda/functions/api_list_classifications/handler.clj` - List classification types with counts
- `lambda/functions/api_list_summaries/handler.clj` - List daily AI summaries
- `lambda/functions/api_list_reports/handler.clj` - List weekly AI reports
- `lambda/shared/api/response.clj` - API response utilities
- `scripts/test-api.sh` - API integration tests
- `scripts/create-cognito-user.sh` - Create test users

## Acceptance Criteria

- [x] Cognito User Pool configured with email-based sign-up
- [x] API Gateway HTTP API with JWT authorization
- [x] 8 API Lambda functions implemented and deployed
- [x] All API endpoints return consistent JSON responses
- [x] Integration test script validates all endpoints
- [x] Terraform resources respect `enable_mobile_api` feature flag
- [x] Unit tests for all API Lambda handlers
- [x] CORS configuration appropriate for native iOS (removed)
- [x] Password auth conditional via `enable_password_auth_for_testing`

## Implementation Steps

- [x] Step 1: Create Cognito User Pool and Identity Pool in Terraform
- [x] Step 2: Create API Gateway HTTP API with JWT authorizer
- [x] Step 3: Implement `api_list_documents` handler
- [x] Step 4: Implement `api_get_document` handler
- [x] Step 5: Implement `api_search` handler
- [x] Step 6: Implement `api_list_tags` handler
- [x] Step 7: Implement `api_documents_by_tag` handler
- [x] Step 8: Implement `api_list_classifications` handler
- [x] Step 9: Implement `api_list_summaries` handler
- [x] Step 10: Implement `api_list_reports` handler
- [x] Step 11: Create shared API response utilities
- [x] Step 12: Write unit tests for all API handlers
- [x] Step 13: Create integration test and user creation scripts
- [x] Step 14: Address PR review feedback (CORS, feature flags, optimization)

## Summary of Changes

- Created Cognito User Pool with email-based authentication
- Created Cognito Identity Pool for federated access
- Set up API Gateway HTTP API with Cognito JWT authorizer
- Implemented 8 API Lambda functions for read-only document access
- Created shared `api.response` utilities for consistent JSON responses
- Added unit tests for all API handlers
- Created `test-api.sh` integration test script and `create-cognito-user.sh`
- Removed CORS (not needed for native iOS client)
- Made resources conditional on `enable_mobile_api` flag
- Optimized classification counts with `SELECT COUNT` instead of fetching all items
- Key commit: `4c75ef7` (#18)
