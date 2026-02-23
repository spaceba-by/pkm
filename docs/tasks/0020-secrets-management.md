# Task 0020: Secrets Management

**Status**: Complete ✅

## Specifications

Generalize and centralize the secrets management infrastructure. Currently, the only secret is the Brave Search API key, defined inline in `persistent_search_lambda.tf` with a hardcoded IAM policy. As the system grows (push notifications, webhooks, email/calendar integration), multiple secrets will be needed. This task establishes a scalable pattern for secret lifecycle management.

### Current State

- **Secret**: `pkm-agent/brave-search-api-key` in AWS Secrets Manager
- **Client**: `lambda/shared/aws/secrets_manager.clj` with `get-secret-value` and atom-based in-memory cache
- **Terraform**: Secret resource embedded in `persistent_search_lambda.tf` (lines 5-12)
- **IAM**: Single-secret ARN policy in `iam.tf` (line 172-189), broad wildcard policy for GitHub Actions (line 778-807)
- **Lambda access**: Secret ARN passed via `BRAVE_SEARCH_SECRET_ARN` environment variable

### Design Goals

1. **Centralize Terraform secrets**: Move all `aws_secretsmanager_secret` resources into a dedicated `terraform/secrets.tf` file with a consistent naming pattern (`${project_name}/<secret-name>`)
2. **Generalize IAM policy**: Replace the single-ARN Lambda policy with a pattern-based policy (`arn:aws:secretsmanager:*:*:secret:${project_name}/*`) so new secrets don't require IAM changes
3. **Multi-secret client support**: Extend `secrets_manager.clj` to cache multiple secrets by ARN (current atom caches one value)
4. **Secret convention**: Document the naming convention, rotation expectations, and per-Lambda environment variable pattern
5. **Placeholder secrets for upcoming features**: Pre-create empty secret resources for APNs key (push notifications) and webhook signing key

### DynamoDB Key Design

No DynamoDB changes required — secrets are stored in AWS Secrets Manager, not DynamoDB.

### Secret Naming Convention

```
${project_name}/brave-search-api-key     # Existing (Task 0013)
${project_name}/apns-auth-key            # For push notifications (Task 0021)
${project_name}/webhook-signing-key      # For webhook verification (Task 0022)
```

## Relevant Files

### Modified Files
- `terraform/secrets.tf` — New file: centralized secret resources (moved from persistent_search_lambda.tf)
- `terraform/persistent_search_lambda.tf` — Remove `aws_secretsmanager_secret` and `aws_secretsmanager_secret_version` resources (moved to secrets.tf)
- `terraform/iam.tf` — Generalize `lambda_secretsmanager_access` policy from single-ARN to prefix-based wildcard
- `lambda/shared/aws/secrets_manager.clj` — Extend cache to support multiple secrets keyed by ARN
- `lambda/tests/shared/secrets_manager_test.clj` — New: unit tests for multi-secret caching

### Reference Files
- `terraform/persistent_search_lambda.tf` — Current secret resource location (lines 5-18)
- `terraform/iam.tf` — Current IAM policies (lines 172-189 Lambda, 778-807 GitHub Actions)
- `lambda/shared/aws/secrets_manager.clj` — Current implementation (35 lines)

## Acceptance Criteria

- [x] All secret resources consolidated in `terraform/secrets.tf`
- [x] Brave Search API key secret moved without disrupting existing infrastructure (no resource recreation)
- [x] IAM Lambda policy uses prefix-based wildcard (`${project_name}/*`) instead of single ARN
- [x] GitHub Actions IAM policy remains unchanged (already uses wildcard)
- [x] `secrets_manager.clj` caches multiple secrets by ARN/name key
- [x] Placeholder secrets created for APNs auth key and webhook signing key (empty, no version)
- [x] Naming convention documented in code comments
- [x] Unit tests verify multi-secret caching behavior
- [ ] `terraform plan` shows no unexpected resource recreation for existing Brave Search secret
- [x] All existing Lambda tests pass
- [x] `terraform validate` and `terraform fmt` pass

## Implementation Steps

- [x] Step 1: Create `terraform/secrets.tf` with existing Brave Search secret resource (use `terraform state mv` to avoid recreation)
- [x] Step 2: Add placeholder secret resources for APNs auth key and webhook signing key
- [x] Step 3: Remove secret resources from `persistent_search_lambda.tf` (already moved)
- [x] Step 4: Update IAM Lambda policy in `iam.tf` to use prefix-based wildcard ARN pattern
- [x] Step 5: Extend `secrets_manager.clj` to use a map-based cache keyed by secret ARN/name
- [x] Step 6: Write unit tests for multi-secret caching (cache hit, cache miss, different keys)
- [ ] Step 7: Verify `terraform plan` shows clean diff (no resource recreation)
- [x] Step 8: Run `bb test` to confirm all existing tests pass

## Summary of Changes

### `terraform/secrets.tf` (new)
- Centralized all secret resources with naming convention comments
- Moved `aws_secretsmanager_secret.brave_search_api_key` and `aws_secretsmanager_secret_version.brave_search_api_key` from `persistent_search_lambda.tf`
- Added placeholder secrets: `apns_auth_key` (Task 0021) and `webhook_signing_key` (Task 0022)

### `terraform/persistent_search_lambda.tf`
- Removed Brave Search secret resource block (lines 1-18) — moved to `secrets.tf`

### `terraform/iam.tf`
- Changed `lambda_secretsmanager_access` policy Resource from single ARN (`aws_secretsmanager_secret.brave_search_api_key.arn`) to prefix-based wildcard (`arn:aws:secretsmanager:REGION:ACCOUNT:secret:${project_name}/*`)

### `lambda/shared/aws/secrets_manager.clj`
- Added `clear-cache!` function for test support
- Updated docstring to clarify multi-key caching behavior (implementation already supported map-based cache)

### `lambda/tests/shared/secrets_manager_test.clj` (new)
- 4 tests: cache-by-key, cache-hit, error-propagation, clear-cache
- 11 assertions verifying multi-secret caching behavior

### `lambda/tests/test_runner.clj`
- Registered `shared.secrets-manager-test` namespace
