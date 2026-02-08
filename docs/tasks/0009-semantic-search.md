# Task 0009: Semantic Search

**Status**: Planned

## Specifications

Integrate OpenSearch for full-text search with relevance scoring. The current `api_search` Lambda uses client-side filtering (fetching up to 500 documents and filtering in memory), which has O(n) performance. OpenSearch will provide proper full-text search with ranking, filtering by date range and classification, and scalability beyond 1000+ documents.

## Relevant Files

- `lambda/functions/api_search/handler.clj` - Current search implementation (to be updated)
- `terraform/` - OpenSearch domain configuration (to be created)
- `lambda/shared/aws/` - OpenSearch client (to be created)
- `docs/ISSUES.md` - Documents the search performance limitation

## Acceptance Criteria

- [ ] OpenSearch domain deployed via Terraform
- [ ] Documents indexed on creation/update via Lambda trigger
- [ ] Full-text search with relevance scoring
- [ ] Filter by date range, classification, and tags
- [ ] Search results include highlighted matching text
- [ ] `api_search` Lambda updated to query OpenSearch
- [ ] Backfill script to index existing documents
- [ ] Search performance under 500ms for typical queries
- [ ] Unit tests for search Lambda and indexing

## Implementation Steps

- [ ] Step 1: Create OpenSearch domain in Terraform
- [ ] Step 2: Define document index mapping (fields, analyzers)
- [ ] Step 3: Create OpenSearch client wrapper in shared library
- [ ] Step 4: Add Lambda trigger to index documents on S3 events
- [ ] Step 5: Update `api_search` to query OpenSearch
- [ ] Step 6: Add support for date range and classification filters
- [ ] Step 7: Add search result highlighting
- [ ] Step 8: Create backfill script for existing documents
- [ ] Step 9: Write unit tests
- [ ] Step 10: Update iOS search view to use new capabilities
