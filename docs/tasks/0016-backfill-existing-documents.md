# Task 0016: Backfill Pre-Existing Documents

**Status**: Planned

## Specifications

Documents from 2021+ exist in the S3 vault but were never processed by the PKM system — they have no DynamoDB metadata, classification, or entity extraction records. Create a Babashka CLI script that identifies unprocessed documents by comparing S3 objects against DynamoDB METADATA records, then triggers the existing Lambda processing pipeline (extract_metadata, classify_document, extract_entities) for each missing document.

### Scale

Expected 500-2000 pre-existing documents. At ~600ms per document (3 Lambda invocations with 200ms spacing), full backfill takes 5-20 minutes.

### Detection Logic

1. List all `.md` files in S3 (paginated), excluding `_agent/` and `.obsidian/`
2. Scan all METADATA records from DynamoDB (paginated via `scan-all`)
3. Set difference = documents needing backfill

### Processing

For each missing document, async-invoke the same 3 Lambdas that EventBridge normally triggers on S3 upload, using the same event format:
```clojure
{:detail {:bucket {:name bucket-name} :object {:key s3-key}}}
```

## Relevant Files

- `scripts/backfill.clj` - New CLI script
- `lambda/shared/aws/s3.clj` - Add paginated `list-all-objects` function
- `lambda/shared/aws/dynamodb.clj` - Existing `scan-all` for METADATA records
- `lambda/shared/aws/lambda.clj` - Existing `invoke-async` for triggering Lambdas
- `lambda/functions/extract_metadata/handler.clj` - Target Lambda
- `lambda/functions/classify_document/handler.clj` - Target Lambda
- `lambda/functions/extract_entities/handler.clj` - Target Lambda

## Acceptance Criteria

- [ ] Paginated S3 listing handles >1000 objects correctly
- [ ] Script identifies documents in S3 that have no METADATA record in DynamoDB
- [ ] Dry-run mode (default) shows count and sample paths without triggering anything
- [ ] Execute mode triggers all 3 processing Lambdas for each missing document
- [ ] Rate limiting prevents Bedrock throttling (configurable delay)
- [ ] Supports `--prefix` to scope to a subdirectory
- [ ] Supports `--limit` to cap the number of documents processed
- [ ] Progress output shows documents processed and errors
- [ ] All existing tests continue to pass

## Implementation Steps

- [x] Step 1: Add `list-all-objects` to `lambda/shared/aws/s3.clj` - Paginated S3 ListObjectsV2 using ContinuationToken, returns all matching keys. Filter for `.md` suffix, exclude `_agent/` and `.obsidian/` prefixes.
- [x] Step 2: Create `scripts/backfill.clj` - Babashka CLI script with `--dry-run` (default), `--execute`, `--prefix`, `--limit`, and `--delay` options. Uses shared AWS libraries. Lists S3 objects, scans DynamoDB, computes diff, triggers Lambdas with rate limiting.
- [ ] Step 3: Verify - Run dry-run to confirm detection works, process a small batch with `--limit 10`, check DynamoDB and CloudWatch for results.
