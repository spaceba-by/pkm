# Task 0015: Document Deletion Cleanup

**Status**: In Progress

## Specifications

When files are deleted from the Obsidian vault, rclone removes them from S3, but DynamoDB metadata records remain stale. This causes errors during bulk reclassification and leaves orphaned data. Add a `delete_document` Lambda triggered by S3 "Object Deleted" EventBridge events to cascade-delete all related DynamoDB records (METADATA, tag index, entity index). Also update bulk_reclassify to clean up stale records it encounters.

### DynamoDB records per document

For a document at `notes/meeting.md` with tags `[a, b]` and entities `{people: ["John"], concepts: ["AI"]}`:

| Record | PK | SK |
|--------|----|----|
| METADATA | `notes/meeting.md` | `METADATA` |
| Tag index (per tag) | `tag#a`, `tag#b` | `doc#notes/meeting.md` |
| Entity index (per entity) | `entity#people#john`, `entity#concepts#ai` | `doc#notes/meeting.md` |

The METADATA record contains `tags` and `entities` fields needed to locate related index records.

## Relevant Files

- `lambda/shared/deletion.clj` - Shared cascade deletion logic
- `lambda/functions/delete_document/handler.clj` - New deletion handler
- `lambda/functions/bulk_reclassify/handler.clj` - Add stale record cleanup
- `lambda/shared/aws/dynamodb.clj` - Existing `delete-item`, `get-item` functions
- `terraform/eventbridge.tf` - Add "Object Deleted" rule and target
- `terraform/lambda.tf` - Add delete_document Lambda definition and log group
- `lambda/build.clj` - Register new function
- `lambda/bb.edn` - Add delete_document to classpath
- `lambda/tests/shared/deletion_test.clj` - Cascade deletion unit tests
- `lambda/tests/delete_document/handler_test.clj` - Handler unit tests

## Acceptance Criteria

- [x] New `delete_document` Lambda deletes METADATA, tag index, and entity index records
- [x] EventBridge rule triggers `delete_document` on S3 "Object Deleted" events for `.md` files
- [x] Deletion is idempotent (no error if records already deleted)
- [x] `_agent/` and `.obsidian/` paths are skipped
- [x] `bulk_reclassify` cleans up stale DynamoDB records when S3 object is missing
- [x] Unit tests cover deletion logic
- [ ] All existing tests continue to pass

## Implementation Steps

- [x] Step 1: Create `delete_document` Lambda handler - Created `shared/deletion.clj` with `cascade-delete-document` function and `functions/delete_document/handler.clj` with EventBridge event handling and `should-skip?` filtering.
- [x] Step 2: Terraform infrastructure - Added `delete-document` to log group set in `lambda.tf`, added `aws_lambda_function.delete_document` resource (10s timeout, 256MB, only needs `DYNAMODB_TABLE_NAME`), added EventBridge rule for `detail-type = ["Object Deleted"]` with `.md` suffix filter excluding `_agent/`, added target and Lambda permission in `eventbridge.tf`.
- [x] Step 3: Build registration - Added `"delete_document" "handler/handler"` to the `functions` map in `lambda/build.clj` and path to `lambda/bb.edn`.
- [x] Step 4: Bulk reclassify stale cleanup - Updated `bulk_reclassify` to call `shared.deletion/cascade-delete-document` when S3 object is missing instead of just skipping.
- [x] Step 5: Unit tests - Created `deletion_test.clj` (5 tests: cascade with tags/entities, idempotent, no tags, empty collections, entity lowercasing) and `handler_test.clj` (3 tests: should-skip?, response shape, event parsing). Registered in test runner.
- [ ] Step 6: Verify - Run `bb test`, `terraform fmt`, `terraform validate`, and `bb build.clj delete_document`.

## Summary of Changes

### New files
- `lambda/shared/deletion.clj` - Shared `cascade-delete-document` function that looks up METADATA record, extracts tags/entities, and cascade-deletes all related DynamoDB index records. Idempotent (no-op if METADATA already gone).
- `lambda/functions/delete_document/handler.clj` - Lambda handler triggered by S3 "Object Deleted" EventBridge events. Parses event, applies `should-skip?` filter, delegates to shared deletion logic.
- `lambda/tests/shared/deletion_test.clj` - Unit tests for cascade deletion logic using `with-redefs` to mock DynamoDB.
- `lambda/tests/delete_document/handler_test.clj` - Unit tests for handler's skip logic, response shapes, and event parsing.

### Modified files
- `terraform/lambda.tf` - Added `delete-document` to CloudWatch log group set, added `aws_lambda_function.delete_document` resource (10s/256MB, DynamoDB-only env).
- `terraform/eventbridge.tf` - Added `s3_markdown_deleted` EventBridge rule (Object Deleted, .md suffix, excludes _agent/), target, and Lambda permission.
- `lambda/build.clj` - Registered `delete_document` in functions map.
- `lambda/bb.edn` - Added `functions/delete_document` to classpath.
- `lambda/functions/bulk_reclassify/handler.clj` - Added `shared.deletion` require; when S3 object is missing during bulk reclassify, now calls `cascade-delete-document` to clean up stale DynamoDB records.
- `lambda/tests/test_runner.clj` - Registered `shared.deletion-test` and `delete-document.handler-test` namespaces.
