# Implementation Plan: Task 0015 — Document Deletion Cleanup

## Overview

When files are deleted from the Obsidian vault, rclone removes them from S3 but DynamoDB metadata records remain orphaned. This task adds a `delete_document` Lambda triggered by S3 "Object Deleted" EventBridge events that cascade-deletes all related DynamoDB records, and updates `bulk_reclassify` to clean up stale records it encounters.

## Step 1: Create `delete_document` Lambda handler

**File:** `lambda/functions/delete_document/handler.clj`

Create the new handler following the established pattern from `extract_metadata/handler.clj`:

- **Namespace:** `handler` with requires for `aws.dynamodb`, `cheshire.core`, `clojure.string`
- **`should-skip?`** function: skip non-`.md` files, `_agent/` prefix, `.obsidian/` prefix (same pattern as other handlers)
- **`cascade-delete-document`** function (core logic, extracted for reuse by `bulk_reclassify` in Step 4):
  1. `ddb/get-item` the METADATA record using `{:PK object-key :SK "METADATA"}`
  2. If METADATA is nil (already deleted), log and return early — idempotent
  3. Extract `:tags` vector from the METADATA record
  4. For each tag: `ddb/delete-item` with `{:PK (str "tag#" tag) :SK (str "doc#" object-key)}`
  5. Extract `:entities` map (e.g., `{:people ["John"] :concepts ["AI"]}`) from the METADATA record
  6. For each `[entity-type entity-list]` and each `entity-name`: `ddb/delete-item` with `{:PK (str "entity#" (name entity-type) "#" (str/lower-case entity-name)) :SK (str "doc#" object-key)}`
  7. Delete the METADATA record: `ddb/delete-item` with `{:PK object-key :SK "METADATA"}`
  8. Return a summary map `{:document object-key :deleted-tags N :deleted-entities N}`
- **`handler`** function:
  1. Parse event from `(:body request)` via `json/parse-string`
  2. Extract `bucket-name` and `object-key` from `(:detail event)`
  3. Validate presence of both
  4. If `should-skip?` → return 200 with "Skipped" message
  5. Otherwise call `cascade-delete-document` and return 200 with result
  6. Catch exceptions → log, print stack trace, return 500

**Key detail:** The `cascade-delete-document` function will be placed in a shared namespace (`shared/deletion.clj`) so `bulk_reclassify` can also use it. Actually, looking at the codebase pattern, shared code goes in `lambda/shared/`. However, to minimize scope and follow the simpler pattern used elsewhere, I'll define the cascade logic directly in `delete_document/handler.clj` and duplicate the core logic inline in `bulk_reclassify`. The deletion logic is ~15 lines and duplication is simpler than adding a new shared module. **Alternative:** Extract to `shared/deletion.clj` for DRY. I'll go with the shared approach since both handlers need the exact same cascade logic.

**Decision: Create `lambda/shared/deletion.clj`** with:
- `cascade-delete-document [table-name object-key]` — the core cascade delete logic
- Both `delete_document/handler.clj` and `bulk_reclassify/handler.clj` will require it

## Step 2: Create shared deletion module

**File:** `lambda/shared/deletion.clj`

```clojure
(ns shared.deletion
  (:require [aws.dynamodb :as ddb]
            [clojure.string :as str]))

(defn cascade-delete-document
  "Cascade-delete all DynamoDB records for a document.
   Deletes tag index entries, entity index entries, and the METADATA record.
   Idempotent: returns gracefully if METADATA is already gone."
  [table-name object-key]
  ...)
```

## Step 3: Terraform infrastructure

**File:** `terraform/lambda.tf` — add two things:

1. Add `"delete-document"` to the `for_each` set in `aws_cloudwatch_log_group.lambda_logs` (line 18-26)
2. Add new `aws_lambda_function.delete_document` resource:
   - `function_name = "${var.project_name}-delete-document"`
   - `timeout = 10`, `memory_size = 256` (lightweight — only DynamoDB operations)
   - Environment: only `DYNAMODB_TABLE_NAME` (no S3 or Bedrock needed)
   - Same pattern as `extract_metadata` (local/S3 source, DLQ, tracing, lifecycle)

**File:** `terraform/eventbridge.tf` — add three resources:

1. `aws_cloudwatch_event_rule.s3_markdown_deleted` — EventBridge rule:
   - `detail-type = ["Object Deleted"]`
   - `.md` suffix filter
   - `anything-but` prefix `_agent/` exclusion (same as the existing exclude_agent rule)
2. `aws_cloudwatch_event_target.delete_document` — target pointing to the new Lambda
3. `aws_lambda_permission.allow_eventbridge_delete_document` — permission for EventBridge to invoke Lambda

## Step 4: Build registration

**File:** `lambda/build.clj`

Add `"delete_document" "handler/handler"` to the `functions` map (after `bulk_reclassify`).

## Step 5: Update bulk_reclassify for stale cleanup

**File:** `lambda/functions/bulk_reclassify/handler.clj`

Currently at lines 81-83, when S3 object is missing, it just logs and increments `skipped-missing`. Change to:

1. Add `[shared.deletion :as deletion]` to the requires
2. In the `(do (println "Skipping missing S3 object:" s3-key) ...)` branch, call `(deletion/cascade-delete-document ddb-table s3-key)` before incrementing the counter
3. Rename counter from `skipped-missing` to `cleaned-stale` and update the response key from `:skipped_missing` to `:cleaned_stale` (keeping `:skipped_missing` as well for backward compatibility, or just changing it since the API response isn't a public contract)
4. Log the cleanup action: `"Cleaning up stale DynamoDB records for missing S3 object:"`

## Step 6: Unit tests

**File:** `lambda/tests/shared/deletion_test.clj`

Tests for the core deletion logic using `with-redefs` to mock DynamoDB calls:

1. **`cascade-delete-with-tags-and-entities-test`** — Mock `ddb/get-item` to return a METADATA record with tags `["a" "b"]` and entities `{:people ["John"] :concepts ["AI"]}`. Verify `ddb/delete-item` is called exactly 5 times (2 tags + 2 entities + 1 METADATA) with the correct PK/SK keys.
2. **`cascade-delete-idempotent-test`** — Mock `ddb/get-item` to return nil (already deleted). Verify `ddb/delete-item` is never called. Verify function returns without error.
3. **`cascade-delete-no-tags-or-entities-test`** — Mock `ddb/get-item` to return METADATA with nil tags and nil entities. Verify only 1 `ddb/delete-item` call (METADATA record only).
4. **`cascade-delete-empty-tags-and-entities-test`** — METADATA with empty `[]` tags and `{}` entities. Verify only 1 delete (METADATA).

**File:** `lambda/tests/delete_document/handler_test.clj`

Tests for the handler:

1. **`should-skip-test`** — Test that `_agent/`, `.obsidian/`, non-`.md` files return true; normal `.md` returns false.
2. **`handler-skip-test`** — Full handler call with `_agent/summary.md` event, verify 200 response with "Skipped" in body.
3. **`handler-success-test`** — Full handler call with valid event, mock `cascade-delete-document`, verify 200 response.
4. **`handler-error-test`** — Mock cascade to throw, verify 500 response.

Register both test namespaces in `lambda/tests/test_runner.clj`.

## Step 7: Verify

1. Run `bb test` from `lambda/` — all existing + new tests pass
2. Run `bb build.clj delete_document` — builds successfully
3. Run `terraform fmt` and `terraform validate` from `terraform/`

## Files to create

- `lambda/shared/deletion.clj`
- `lambda/functions/delete_document/handler.clj`
- `lambda/tests/shared/deletion_test.clj`
- `lambda/tests/delete_document/handler_test.clj`

## Files to modify

- `terraform/lambda.tf` — add log group entry + Lambda function resource
- `terraform/eventbridge.tf` — add rule, target, permission for "Object Deleted"
- `lambda/build.clj` — add `delete_document` to functions map
- `lambda/functions/bulk_reclassify/handler.clj` — add stale cleanup with shared deletion
- `lambda/tests/test_runner.clj` — register new test namespaces
- `docs/tasks/0015-document-deletion-cleanup.md` — update status as steps complete
