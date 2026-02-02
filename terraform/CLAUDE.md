# Terraform Guidelines

This file provides guidance for working with Terraform in this repository.

## Required Commands

**Always run these before committing changes:**

```bash
terraform fmt       # Format all .tf files
terraform validate  # Validate configuration syntax
```

## Common Workflows

```bash
# Preview changes
terraform plan

# Apply changes
terraform apply

# Plan with specific variables (for CI/CD)
terraform plan -var="lambda_source_type=s3" -var="lambda_build_tag=main-abc123"
```

## File Organization

| File | Purpose |
|------|---------|
| `main.tf` | Provider configuration, data sources |
| `variables.tf` | Input variables with descriptions and defaults |
| `outputs.tf` | Output values for other systems |
| `iam.tf` | IAM roles and policies |
| `s3.tf` | Vault S3 bucket |
| `s3_artifacts.tf` | Lambda artifacts bucket |
| `dynamodb.tf` | Metadata table |
| `lambda.tf` | Processing Lambda functions (6) |
| `api_lambda.tf` | API Lambda functions (8) |
| `api_gateway.tf` | HTTP API Gateway with routes |
| `cognito.tf` | User Pool, App Client, Identity Pool |
| `eventbridge.tf` | Event rules and schedules |
| `stepfunctions.tf` | Weekly report workflow |
| `cloudwatch.tf` | Dashboards, alarms, log groups |
| `state.tf` | Remote state backend configuration |

## Naming Conventions

- Resources: `pkm-agent-{resource-name}` (e.g., `pkm-agent-classify-document`)
- Variables: `snake_case` (e.g., `lambda_source_type`)
- Locals: `snake_case` (e.g., `use_local_source`)
- Outputs: `snake_case` (e.g., `api_gateway_url`)

## Lambda Source Types

The `lambda_source_type` variable controls how Lambda code is deployed:

- `local` (default): Uses `../lambda/target/*.zip` files - requires building locally first
- `s3`: Uses artifacts from S3 bucket - used by CI/CD pipeline

```bash
# Local development (requires: cd lambda && bb build.clj)
terraform plan

# CI/CD or when zips don't exist locally
terraform plan -var="lambda_source_type=s3" -var="lambda_build_tag=main-abc123"
```

## Conditional Resources

Several resources use `for_each` with enable flags:

```hcl
# Example: GitHub OIDC provider
resource "aws_iam_openid_connect_provider" "github" {
  for_each = var.enable_github_oidc ? { "enabled" = true } : {}
  ...
}
```

Key enable flags:
- `enable_github_oidc` - GitHub Actions OIDC authentication
- `enable_mobile_api` - Cognito and API Gateway (default: true)
- `cognito_deletion_protection` - Prevent accidental User Pool deletion

## Adding New Lambda Functions

1. Add the function definition to `lambda.tf` or `api_lambda.tf`
2. Add CloudWatch log group
3. Add IAM permissions if needed
4. For API functions: add route in `api_gateway.tf`
5. Run `terraform fmt && terraform validate`

## State Management

- State is stored in S3 with DynamoDB locking
- State bucket: `pkm-tfstate`
- Lock table: `pkm-agent-terraform-state-lock`
- Never manually edit state files

## Sensitive Values

- Never commit `.tfvars` files with secrets
- Use environment variables or AWS Secrets Manager
- The `cognito.tf` app client has `generate_secret = false` for iOS compatibility
