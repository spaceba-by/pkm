# Task 0015: Document Deletion Cleanup

**Status**: Planned

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

- `lambda/functions/delete_document/handler.clj` - New deletion handler
- `lambda/functions/bulk_reclassify/handler.clj` - Add stale record cleanup
- `lambda/shared/aws/dynamodb.clj` - Existing `delete-item`, `get-item` functions
- `terraform/eventbridge.tf` - Add "Object Deleted" rule and target
- `terraform/lambda.tf` - Add delete_document Lambda definition and log group
- `lambda/build.clj` - Register new function
- `lambda/tests/` - Unit tests for deletion logic

## Acceptance Criteria

- [ ] New `delete_document` Lambda deletes METADATA, tag index, and entity index records
- [ ] EventBridge rule triggers `delete_document` on S3 "Object Deleted" events for `.md` files
- [ ] Deletion is idempotent (no error if records already deleted)
- [ ] `_agent/` and `.obsidian/` paths are skipped
- [ ] `bulk_reclassify` cleans up stale DynamoDB records when S3 object is missing
- [ ] Unit tests cover deletion logic
- [ ] All existing tests continue to pass

## Implementation Steps

- [ ] Step 1: Create `delete_document` Lambda handler - Receive S3 delete event, look up METADATA record for tags/entities, cascade-delete all related DynamoDB records (tag index entries, entity index entries, METADATA record). Use `should-skip?` pattern from other handlers.
- [ ] Step 2: Terraform infrastructure - Add `delete-document` to log group set in `lambda.tf`, add `aws_lambda_function.delete_document` resource (10s timeout, 256MB, only needs `DYNAMODB_TABLE_NAME`), add EventBridge rule for `detail-type = ["Object Deleted"]` with `.md` suffix filter excluding `_agent/`, add target and Lambda permission in `eventbridge.tf`.
- [ ] Step 3: Build registration - Add `"delete_document" "handler/handler"` to the `functions` map in `lambda/build.clj`.
- [ ] Step 4: Bulk reclassify stale cleanup - When `bulk_reclassify` detects a missing S3 object, delete the stale DynamoDB records (same cascade logic as `delete_document`) instead of just skipping.
- [ ] Step 5: Unit tests - Test deletion with tags and entities, test idempotent deletion when METADATA is already gone, test `should-skip?` filtering, test handler response shape.
- [ ] Step 6: Verify - Run `bb test`, `terraform fmt`, `terraform validate`, and `bb build.clj delete_document`.
