# Known Issues and Future Enhancements

This document tracks known limitations, technical debt, and planned enhancements for the PKM system.

## Open Issues

### Scalability

#### Search Performance (api_search)
- **Issue**: Client-side filtering implementation fetches up to 500 documents and filters in memory
- **Impact**: O(n) performance, not suitable for very large vaults (1000+ documents)
- **Solution**: Implement OpenSearch/Elasticsearch integration for full-text search with relevance scoring
- **Priority**: Medium - acceptable for current use case

#### Tag Listing (api_list_tags)
- **Issue**: DynamoDB scan limited to 1000 documents
- **Impact**: Vaults with 1000+ documents won't have accurate tag counts
- **Solution**: Implement pagination with continuation tokens, or create a separate tag aggregation table updated via DynamoDB Streams
- **Priority**: Low - most PKM vaults are under 1000 documents

#### Documents by Tag (api_documents_by_tag)
- **Issue**: N+1 query pattern - one DynamoDB GetItem call per document
- **Impact**: Latency increases linearly with result count
- **Solution**: Use DynamoDB BatchGetItem to fetch multiple documents in a single request (max 100 items per batch)
- **Priority**: Medium - noticeable with large tag result sets

### Pagination

#### S3 Object Listing (api_list_summaries, api_list_reports)
- **Issue**: S3 list-objects has a 1000 object limit per request
- **Impact**: Would affect summaries after 2.7+ years, reports after 19+ years
- **Solution**: Implement continuation token pagination if needed
- **Priority**: Low - will not be an issue for years

### Concurrency

#### extract_metadata Race Condition with put-item
- **Issue**: `extract_metadata` uses `ddb/put-item` (full replace) for the METADATA row, while `classify_document` uses `ddb/update-item`. If `extract_metadata` writes after `classify_document`, it overwrites classification-related fields (`:classification`, `:classification_confidence`, `:classification_override`, `entities`, etc.)
- **Impact**: Intermittent data loss when both Lambdas process the same document concurrently. Mitigated by Step Functions ordering (extract_metadata runs first) and by `classify_document` using `update-item`.
- **Solution**: Convert `extract_metadata` from `put-item` to `update-item` so parser-derived fields are updated without clobbering classification attributes
- **Priority**: Medium - mitigated by current ordering but not eliminated
- **Reference**: PR #63 review comment

### Test Stability

#### InsightsViewSnapshotTests.test_summariesTab() flaky in CI
- **Issue**: `InsightsViewSnapshotTests.test_summariesTab()` snapshot test fails intermittently in CI
- **Location**: `ios/PKMReaderTests/Snapshots/Screens/InsightsViewSnapshotTests.swift`
- **Impact**: CI pipeline produces false-negative test failures, requiring manual re-runs
- **Likely Cause**: The test calls `assertDeviceSnapshotAfterTask` which waits for async tasks to complete before capturing a snapshot. Timing differences in CI (slower runners, resource contention) may cause the view to be captured before the mock data has fully rendered.
- **Priority**: Medium - reduces confidence in CI results

### Security

#### Admin Routes Authorization
- **Issue**: Future admin routes (write operations, user management) will need authorization beyond JWT validation
- **Impact**: Current read-only API is secure, but write operations need additional controls
- **Solution**: Implement Cognito user groups with group-based access control for admin operations
- **Priority**: Medium - needed before implementing write endpoints

#### Password Auth Flow
- **Issue**: `ALLOW_USER_PASSWORD_AUTH` is less secure than SRP auth
- **Impact**: Password transmitted directly (over HTTPS, but less ideal than SRP)
- **Solution**: Use `enable_password_auth_for_testing = false` (default) in production, only enable for local testing
- **Priority**: N/A - controlled by configuration

## Completed

### Phase 1 Review Fixes (PR #18)
- [x] Terraform conditional resources respect `enable_mobile_api` flag
- [x] CORS removed from API Gateway (not needed for native iOS)
- [x] Password auth made conditional via `enable_password_auth_for_testing` variable
- [x] Classification counts use SELECT COUNT instead of fetching all items
- [x] Documentation comments added to handlers about scalability limits
- [x] Test file docstring explains why handler functions are duplicated
- [x] Password masked in create-cognito-user.sh output

## Future Enhancements

### Search
- [ ] OpenSearch integration for full-text search
- [ ] Search result ranking/relevance scoring
- [ ] Filter by date range, classification, etc.

### API Features
- [ ] Cursor-based pagination for all list endpoints
- [ ] Batch operations (get multiple documents)
- [ ] WebSocket support for real-time updates

### Security
- [ ] Cognito Advanced Security Mode (adaptive authentication, compromised credentials detection)
- [ ] API key rotation
- [ ] Rate limiting per user
- [ ] Audit logging

### Performance
- [ ] Response caching with API Gateway
- [ ] DynamoDB DAX for hot data
- [ ] Lambda provisioned concurrency for cold start reduction
