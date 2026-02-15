# Task 0014: Classification System Improvements

**Status**: Complete

## Specifications

Improve the classification system to produce more accurate results. The current prompt is minimal with no category descriptions, no metadata signals, and no system prompt. Additionally, add a feedback/correction API, bulk reclassification tooling, optimize the classification index schedule, and integrate reclassification into the iOS app.

## Relevant Files

- `lambda/shared/aws/bedrock.clj` - Classification prompt
- `lambda/functions/classify_document/handler.clj` - Classification handler
- `lambda/functions/api_update_classification/handler.clj` - New feedback API
- `lambda/functions/bulk_reclassify/handler.clj` - New bulk reclassify Lambda
- `lambda/functions/api_bulk_reclassify/handler.clj` - New bulk reclassify API
- `terraform/api_lambda.tf` - API Lambda definitions
- `terraform/api_gateway.tf` - API routes
- `terraform/lambda.tf` - Processing Lambda definitions
- `terraform/eventbridge.tf` - EventBridge schedules
- `lambda/build.clj` - Build registration
- `lambda/tests/shared/classification_test.clj` - New classification tests
- `ios/PKMReader/Core/Networking/APIClientProtocol.swift` - Protocol update
- `ios/PKMReader/Core/Networking/APIClient.swift` - iOS API client
- `ios/PKMReader/Features/DocumentDetail/DocumentDetailViewModel.swift` - Document detail VM
- `ios/PKMReader/Features/DocumentDetail/DocumentDetailView.swift` - Document detail view
- `scripts/bulk-reclassify.sh` - CLI convenience script

## Acceptance Criteria

- [x] Classification prompt includes system prompt, category descriptions, metadata signals
- [x] Classification returns JSON with confidence score
- [x] Confidence stored in DynamoDB alongside classification
- [x] PUT /documents/{key+}/classification API endpoint for manual overrides
- [x] Override flag prevents automatic reclassification
- [x] Bulk reclassification Lambda with dry-run and filtering
- [x] POST /admin/reclassify API endpoint triggers bulk work async
- [x] Classification index updated on schedule (6h) instead of per-document
- [x] iOS ClassificationBadge is tappable with picker to change classification
- [x] Unit tests for new functionality

## Implementation Steps

- [x] Step 1: Enhanced classification prompt - Rewrite `bedrock/classify-document` with system prompt, metadata signals, JSON response with confidence
- [x] Step 2: Update classify_document handler - Consume new return format, store confidence in DynamoDB, check for override before reclassifying
- [x] Step 3: Classification override API - New `api_update_classification` Lambda + Terraform + build
- [x] Step 4: Override check in classify_document - Integrated into Step 2
- [x] Step 5: Bulk reclassify Lambda - New `bulk_reclassify` Lambda with dry-run, filtering, override respect
- [x] Step 6: Bulk reclassify API - New `api_bulk_reclassify` Lambda that triggers bulk work async + CLI script
- [x] Step 7: Index optimization - Remove per-doc trigger, add EventBridge schedule (rate 6 hours)
- [x] Step 8: iOS reclassification UI - Add PUT method to APIClient, tappable ClassificationBadge with Menu picker, view model update logic
- [x] Step 9: Tests - Unit tests for prompt parsing, override logic, bulk filtering, classification validation (31 tests, 225 assertions passing)

## Summary of Changes

### Backend (Lambda/Clojure)
- **bedrock.clj**: Rewrote `classify-document` with detailed system prompt describing each category with signals, enriched user prompt with tags/frontmatter-type/wikilink-count, returns `{:classification :confidence}` map with JSON parsing
- **classify_document/handler.clj**: Consumes new `{:classification :confidence}` format, stores `classification_confidence` in DynamoDB, checks for `classification_override` before reclassifying (skips with graceful 200), removed per-document index trigger
- **api_update_classification/handler.clj**: New Lambda for `PUT /documents/{key+}/classification` — validates input, sets `classification_override: true` and `classification_overridden_at` in DynamoDB
- **bulk_reclassify/handler.clj**: New Lambda that scans all METADATA items, filters out overrides and optionally by classification, invokes classify_document async for each; supports `dry_run` mode
- **api_bulk_reclassify/handler.clj**: New API Lambda for `POST /admin/reclassify` — invokes bulk_reclassify sync for dry-run, async for actual reclassification
- **build.clj / bb.edn**: Registered 3 new functions

### Infrastructure (Terraform)
- **api_lambda.tf**: Added `api_update_classification` and `api_bulk_reclassify` Lambda resources
- **api_gateway.tf**: Added `PUT /documents/{key+}/classification` and `POST /admin/reclassify` routes with JWT auth, plus Lambda permissions
- **lambda.tf**: Added `bulk_reclassify` Lambda (300s timeout), removed `UPDATE_INDEX_LAMBDA` env var from classify_document, added `bulk-reclassify` to log group list
- **eventbridge.tf**: Added `rate(6 hours)` schedule for `update_classification_index` Lambda

### iOS
- **APIClientProtocol.swift**: Added `updateClassification(documentId:classification:)` method
- **APIClient.swift**: Implemented PUT request with retry logic (`performPutRequestWithRetry`/`performPutRequest`)
- **DocumentDetailViewModel.swift**: Added `classification` published property, `isUpdatingClassification` state, `classificationUpdateError`, and `updateClassification(to:)` method
- **DocumentDetailView.swift**: Replaced static `ClassificationBadge` with `Menu` picker showing all 5 classification types, includes loading indicator and error alert
- Updated all `APIClientProtocol` conformances: `PreviewAPIClient` (2 instances), `UITestAPIClient`, `MockAPIClient`

### Tests
- **classification_test.clj**: New test file with 8 tests covering JSON response parsing, fallback behavior, override flag logic, bulk filtering, and classification validation
- **test_runner.clj**: Registered new test namespace

### Scripts
- **scripts/bulk-reclassify.sh**: CLI script for direct Lambda invocation with `--execute`, `--classification`, and `--lambda-name` flags
