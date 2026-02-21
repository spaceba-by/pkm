# Task 0020: Secrets Management

**Status**: Planned

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

- [ ] All secret resources consolidated in `terraform/secrets.tf`
- [ ] Brave Search API key secret moved without disrupting existing infrastructure (no resource recreation)
- [ ] IAM Lambda policy uses prefix-based wildcard (`${project_name}/*`) instead of single ARN
- [ ] GitHub Actions IAM policy remains unchanged (already uses wildcard)
- [ ] `secrets_manager.clj` caches multiple secrets by ARN/name key
- [ ] Placeholder secrets created for APNs auth key and webhook signing key (empty, no version)
- [ ] Naming convention documented in code comments
- [ ] Unit tests verify multi-secret caching behavior
- [ ] `terraform plan` shows no unexpected resource recreation for existing Brave Search secret
- [ ] All existing Lambda tests pass
- [ ] `terraform validate` and `terraform fmt` pass

## Implementation Steps

- [ ] Step 1: Create `terraform/secrets.tf` with existing Brave Search secret resource (use `terraform state mv` to avoid recreation)
- [ ] Step 2: Add placeholder secret resources for APNs auth key and webhook signing key
- [ ] Step 3: Remove secret resources from `persistent_search_lambda.tf` (already moved)
- [ ] Step 4: Update IAM Lambda policy in `iam.tf` to use prefix-based wildcard ARN pattern
- [ ] Step 5: Extend `secrets_manager.clj` to use a map-based cache keyed by secret ARN/name
- [ ] Step 6: Write unit tests for multi-secret caching (cache hit, cache miss, different keys)
- [ ] Step 7: Verify `terraform plan` shows clean diff (no resource recreation)
- [ ] Step 8: Run `bb test` to confirm all existing tests pass
