# iOS App Phase 1: Backend API Infrastructure - Detailed Implementation Plan

## Overview

Phase 1 establishes the backend API infrastructure required for the iOS app to securely access PKM data. This phase focuses on:

1. **Amazon Cognito** - User authentication and authorization
2. **API Gateway** - REST API endpoints with JWT validation
3. **API Lambda Functions** - Backend logic to serve PKM data

**Prerequisites**: Phase 0 (Build & Test Automation) is complete.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Task Breakdown](#task-breakdown)
3. [1.1 Cognito User Authentication](#11-cognito-user-authentication)
4. [1.2 API Gateway Configuration](#12-api-gateway-configuration)
5. [1.3 API Lambda Functions](#13-api-lambda-functions)
6. [1.4 DynamoDB Index Updates](#14-dynamodb-index-updates)
7. [1.5 Integration Testing](#15-integration-testing)
8. [Deliverables Checklist](#deliverables-checklist)
9. [CI/CD Integration](#cicd-integration)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         iOS App (Future - Phase 2)                       │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │ HTTPS + JWT Bearer Token
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    API Gateway (HTTP API)                                │
│  Base URL: https://api.pkm.spaceba.by                                   │
├─────────────────────────────────────────────────────────────────────────┤
│  GET  /documents              - List documents with pagination           │
│  GET  /documents/{key+}       - Get single document content + metadata   │
│  GET  /search                 - Full-text search                         │
│  GET  /tags                   - List all unique tags                     │
│  GET  /tags/{tag}/documents   - Get documents by tag                     │
│  GET  /classifications        - List document counts by classification   │
│  GET  /summaries              - List daily summaries                     │
│  GET  /reports                - List weekly reports                      │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Cognito JWT Authorizer                                │
│  - Validates JWT tokens from Cognito User Pool                          │
│  - Extracts user identity for audit logging                             │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    Lambda Functions (Babashka/Clojure)                   │
│  pkm-api-list-documents     pkm-api-get-document                        │
│  pkm-api-search             pkm-api-list-tags                           │
│  pkm-api-documents-by-tag   pkm-api-list-summaries                      │
│  pkm-api-list-reports       pkm-api-list-classifications                │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
              ┌──────────────────┴──────────────────┐
              ▼                                     ▼
┌─────────────────────────┐           ┌─────────────────────────┐
│   S3: notes.spaceba.by  │           │  DynamoDB: pkm-metadata │
│   (markdown content)    │           │  (metadata, indexes)    │
└─────────────────────────┘           └─────────────────────────┘
```

---

## Task Breakdown

### Sprint Summary

| Task Group | Est. Effort | Priority | Dependencies |
|------------|-------------|----------|--------------|
| 1.1 Cognito Setup | Medium | High | None |
| 1.2 API Gateway | Medium | High | 1.1 |
| 1.3 Lambda Functions | High | High | 1.2 |
| 1.4 DynamoDB Updates | Low | Medium | None |
| 1.5 Integration Tests | Medium | High | 1.3 |

---

## 1.1 Cognito User Authentication

### 1.1.1 Create Terraform Module

**File**: `terraform/cognito.tf`

```hcl
# =============================================================================
# Cognito User Pool - User Authentication
# =============================================================================

resource "aws_cognito_user_pool" "pkm_users" {
  name = "${var.project_name}-users"

  # Username configuration - use email as username
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy - strong requirements
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  # Account recovery via email
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Email configuration (using Cognito default for now)
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # User attribute schema
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    string_attribute_constraints {
      min_length = 5
      max_length = 256
    }
  }

  # MFA configuration (optional but recommended)
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # Prevent user enumeration attacks
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  # Deletion protection
  deletion_protection = var.environment == "production" ? "ACTIVE" : "INACTIVE"

  tags = merge(var.tags, {
    Name = "${var.project_name}-users"
  })
}

# =============================================================================
# Cognito User Pool Client - iOS App
# =============================================================================

resource "aws_cognito_user_pool_client" "ios_client" {
  name         = "${var.project_name}-ios-client"
  user_pool_id = aws_cognito_user_pool.pkm_users.id

  # IMPORTANT: No client secret for mobile apps (SRP auth)
  generate_secret = false

  # Supported auth flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",        # Secure Remote Password - recommended for mobile
    "ALLOW_REFRESH_TOKEN_AUTH"    # Allow token refresh
  ]

  # Token validity periods
  access_token_validity  = 1    # hours
  id_token_validity      = 1    # hours
  refresh_token_validity = 30   # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Prevent token revocation issues
  enable_token_revocation = true

  # Read-only attributes the app can access
  read_attributes = [
    "email",
    "email_verified"
  ]

  # No write attributes needed for read-only app
  write_attributes = []

  # Callback URLs (not needed for native app auth flow)
  callback_urls = []
  logout_urls   = []

  # Supported identity providers
  supported_identity_providers = ["COGNITO"]
}

# =============================================================================
# Cognito Identity Pool - AWS Credentials (Optional for future use)
# =============================================================================

resource "aws_cognito_identity_pool" "pkm_identity" {
  identity_pool_name               = "${var.project_name}-identity"
  allow_unauthenticated_identities = false
  allow_classic_flow               = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.ios_client.id
    provider_name           = aws_cognito_user_pool.pkm_users.endpoint
    server_side_token_check = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-identity"
  })
}

# =============================================================================
# IAM Roles for Cognito Identity Pool
# =============================================================================

resource "aws_iam_role" "cognito_authenticated" {
  name = "${var.project_name}-cognito-authenticated"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.pkm_identity.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-cognito-authenticated"
  })
}

# Minimal permissions for authenticated users (API access only)
resource "aws_iam_role_policy" "cognito_authenticated_policy" {
  name = "api-access"
  role = aws_iam_role.cognito_authenticated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*"
      }
    ]
  })
}

# Attach roles to identity pool
resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.pkm_identity.id

  roles = {
    "authenticated" = aws_iam_role.cognito_authenticated.arn
  }
}
```

### 1.1.2 Add Cognito Variables

**Add to**: `terraform/variables.tf`

```hcl
# =============================================================================
# Cognito Variables
# =============================================================================

variable "cognito_user_pool_name" {
  description = "Name of the Cognito User Pool"
  type        = string
  default     = "pkm-users"
}

variable "environment" {
  description = "Deployment environment (development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}
```

### 1.1.3 Add Cognito Outputs

**Add to**: `terraform/outputs.tf`

```hcl
# =============================================================================
# Cognito Outputs
# =============================================================================

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.pkm_users.id
}

output "cognito_user_pool_endpoint" {
  description = "Cognito User Pool endpoint"
  value       = aws_cognito_user_pool.pkm_users.endpoint
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID (safe to embed in iOS app)"
  value       = aws_cognito_user_pool_client.ios_client.id
}

output "cognito_identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = aws_cognito_identity_pool.pkm_identity.id
}
```

### 1.1.4 Initial User Setup Script

**File**: `scripts/create-cognito-user.sh`

```bash
#!/bin/bash
# Create initial admin user in Cognito User Pool
# Usage: ./scripts/create-cognito-user.sh <email> <temporary-password>

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <email> <temporary-password>"
    exit 1
fi

EMAIL="$1"
TEMP_PASSWORD="$2"

# Get User Pool ID from Terraform output
USER_POOL_ID=$(cd terraform && terraform output -raw cognito_user_pool_id)

echo "Creating user in User Pool: $USER_POOL_ID"

# Create user with temporary password
aws cognito-idp admin-create-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$EMAIL" \
    --user-attributes Name=email,Value="$EMAIL" Name=email_verified,Value=true \
    --temporary-password "$TEMP_PASSWORD" \
    --message-action SUPPRESS

echo "User created: $EMAIL"
echo "User must change password on first login."
```

---

## 1.2 API Gateway Configuration

### 1.2.1 Create API Gateway Terraform

**File**: `terraform/api_gateway.tf`

```hcl
# =============================================================================
# API Gateway - HTTP API for PKM Mobile
# =============================================================================

resource "aws_apigatewayv2_api" "pkm_api" {
  name          = "${var.project_name}-mobile-api"
  protocol_type = "HTTP"
  description   = "PKM Mobile API for iOS app"

  # CORS configuration for development
  cors_configuration {
    allow_origins     = var.api_allowed_origins
    allow_methods     = ["GET", "OPTIONS"]
    allow_headers     = ["Authorization", "Content-Type", "X-Request-ID"]
    expose_headers    = ["X-Request-ID"]
    max_age           = 300
    allow_credentials = false
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-mobile-api"
  })
}

# =============================================================================
# Cognito JWT Authorizer
# =============================================================================

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.pkm_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.ios_client.id]
    issuer   = "https://${aws_cognito_user_pool.pkm_users.endpoint}"
  }
}

# =============================================================================
# API Stage
# =============================================================================

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.pkm_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId         = "$context.requestId"
      ip                = "$context.identity.sourceIp"
      requestTime       = "$context.requestTime"
      httpMethod        = "$context.httpMethod"
      routeKey          = "$context.routeKey"
      status            = "$context.status"
      responseLength    = "$context.responseLength"
      integrationError  = "$context.integrationErrorMessage"
      userAgent         = "$context.identity.userAgent"
      cognitoSub        = "$context.authorizer.claims.sub"
    })
  }

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-default-stage"
  })
}

# =============================================================================
# CloudWatch Log Group for API Gateway
# =============================================================================

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-mobile-api"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-gateway-logs"
  })
}

# =============================================================================
# API Routes - Documents
# =============================================================================

# GET /documents - List all documents
resource "aws_apigatewayv2_integration" "list_documents" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_documents.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_documents" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /documents"
  target             = "integrations/${aws_apigatewayv2_integration.list_documents.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# GET /documents/{key+} - Get single document (greedy path for nested keys)
resource "aws_apigatewayv2_integration" "get_document" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_get_document.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_document" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /documents/{key+}"
  target             = "integrations/${aws_apigatewayv2_integration.get_document.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# =============================================================================
# API Routes - Search
# =============================================================================

resource "aws_apigatewayv2_integration" "search" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_search.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "search" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /search"
  target             = "integrations/${aws_apigatewayv2_integration.search.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# =============================================================================
# API Routes - Tags
# =============================================================================

resource "aws_apigatewayv2_integration" "list_tags" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_tags.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_tags" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /tags"
  target             = "integrations/${aws_apigatewayv2_integration.list_tags.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_integration" "documents_by_tag" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_documents_by_tag.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "documents_by_tag" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /tags/{tag}/documents"
  target             = "integrations/${aws_apigatewayv2_integration.documents_by_tag.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# =============================================================================
# API Routes - Classifications
# =============================================================================

resource "aws_apigatewayv2_integration" "list_classifications" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_classifications.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_classifications" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /classifications"
  target             = "integrations/${aws_apigatewayv2_integration.list_classifications.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# =============================================================================
# API Routes - Summaries & Reports
# =============================================================================

resource "aws_apigatewayv2_integration" "list_summaries" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_summaries.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_summaries" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /summaries"
  target             = "integrations/${aws_apigatewayv2_integration.list_summaries.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_integration" "list_reports" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_reports.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_reports" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /reports"
  target             = "integrations/${aws_apigatewayv2_integration.list_reports.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# =============================================================================
# Lambda Permissions for API Gateway
# =============================================================================

resource "aws_lambda_permission" "api_list_documents" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_documents.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_get_document" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_get_document.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_search" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_search.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list_tags" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_tags.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_documents_by_tag" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_documents_by_tag.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list_classifications" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_classifications.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list_summaries" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_summaries.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list_reports" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_reports.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}
```

### 1.2.2 Add API Gateway Variables

**Add to**: `terraform/variables.tf`

```hcl
# =============================================================================
# API Gateway Variables
# =============================================================================

variable "api_allowed_origins" {
  description = "Allowed origins for CORS (empty for mobile-only API)"
  type        = list(string)
  default     = ["*"]  # Restrict in production
}

variable "api_throttle_burst_limit" {
  description = "API Gateway burst limit"
  type        = number
  default     = 100
}

variable "api_throttle_rate_limit" {
  description = "API Gateway rate limit per second"
  type        = number
  default     = 50
}
```

### 1.2.3 Add API Gateway Outputs

**Add to**: `terraform/outputs.tf`

```hcl
# =============================================================================
# API Gateway Outputs
# =============================================================================

output "api_gateway_url" {
  description = "API Gateway invocation URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.pkm_api.id
}
```

---

## 1.3 API Lambda Functions

### 1.3.1 Lambda Terraform Configuration

**File**: `terraform/api_lambda.tf`

```hcl
# =============================================================================
# API Lambda Functions
# =============================================================================

locals {
  api_lambda_functions = [
    "api_list_documents",
    "api_get_document",
    "api_search",
    "api_list_tags",
    "api_documents_by_tag",
    "api_list_classifications",
    "api_list_summaries",
    "api_list_reports"
  ]

  api_lambda_environment = {
    S3_BUCKET_NAME      = var.s3_bucket_name
    DYNAMODB_TABLE_NAME = var.dynamodb_table_name
  }
}

# List Documents Lambda
resource "aws_lambda_function" "api_list_documents" {
  function_name = "${var.project_name}-api-list-documents"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.handler"
  runtime       = "provided.al2023"
  architectures = ["x86_64"]
  timeout       = 30
  memory_size   = 256

  filename         = var.lambda_source_type == "local" ? "${path.module}/../lambda/target/api_list_documents.zip" : null
  s3_bucket        = var.lambda_source_type == "s3" ? var.lambda_artifacts_bucket_name : null
  s3_key           = var.lambda_source_type == "s3" ? "builds/${var.lambda_build_tag}/api_list_documents.zip" : null
  source_code_hash = var.lambda_source_type == "local" ? filebase64sha256("${path.module}/../lambda/target/api_list_documents.zip") : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-list-documents"
  })
}

# Get Document Lambda
resource "aws_lambda_function" "api_get_document" {
  function_name = "${var.project_name}-api-get-document"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.handler"
  runtime       = "provided.al2023"
  architectures = ["x86_64"]
  timeout       = 30
  memory_size   = 256

  filename         = var.lambda_source_type == "local" ? "${path.module}/../lambda/target/api_get_document.zip" : null
  s3_bucket        = var.lambda_source_type == "s3" ? var.lambda_artifacts_bucket_name : null
  s3_key           = var.lambda_source_type == "s3" ? "builds/${var.lambda_build_tag}/api_get_document.zip" : null
  source_code_hash = var.lambda_source_type == "local" ? filebase64sha256("${path.module}/../lambda/target/api_get_document.zip") : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-get-document"
  })
}

# Search Lambda
resource "aws_lambda_function" "api_search" {
  function_name = "${var.project_name}-api-search"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.handler"
  runtime       = "provided.al2023"
  architectures = ["x86_64"]
  timeout       = 30
  memory_size   = 256

  filename         = var.lambda_source_type == "local" ? "${path.module}/../lambda/target/api_search.zip" : null
  s3_bucket        = var.lambda_source_type == "s3" ? var.lambda_artifacts_bucket_name : null
  s3_key           = var.lambda_source_type == "s3" ? "builds/${var.lambda_build_tag}/api_search.zip" : null
  source_code_hash = var.lambda_source_type == "local" ? filebase64sha256("${path.module}/../lambda/target/api_search.zip") : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-search"
  })
}

# List Tags Lambda
resource "aws_lambda_function" "api_list_tags" {
  function_name = "${var.project_name}-api-list-tags"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.handler"
  runtime       = "provided.al2023"
  architectures = ["x86_64"]
  timeout       = 30
  memory_size   = 256

  filename         = var.lambda_source_type == "local" ? "${path.module}/../lambda/target/api_list_tags.zip" : null
  s3_bucket        = var.lambda_source_type == "s3" ? var.lambda_artifacts_bucket_name : null
  s3_key           = var.lambda_source_type == "s3" ? "builds/${var.lambda_build_tag}/api_list_tags.zip" : null
  source_code_hash = var.lambda_source_type == "local" ? filebase64sha256("${path.module}/../lambda/target/api_list_tags.zip") : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-list-tags"
  })
}

# Documents by Tag Lambda
resource "aws_lambda_function" "api_documents_by_tag" {
  function_name = "${var.project_name}-api-documents-by-tag"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.handler"
  runtime       = "provided.al2023"
  architectures = ["x86_64"]
  timeout       = 30
  memory_size   = 256

  filename         = var.lambda_source_type == "local" ? "${path.module}/../lambda/target/api_documents_by_tag.zip" : null
  s3_bucket        = var.lambda_source_type == "s3" ? var.lambda_artifacts_bucket_name : null
  s3_key           = var.lambda_source_type == "s3" ? "builds/${var.lambda_build_tag}/api_documents_by_tag.zip" : null
  source_code_hash = var.lambda_source_type == "local" ? filebase64sha256("${path.module}/../lambda/target/api_documents_by_tag.zip") : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-documents-by-tag"
  })
}

# List Classifications Lambda
resource "aws_lambda_function" "api_list_classifications" {
  function_name = "${var.project_name}-api-list-classifications"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.handler"
  runtime       = "provided.al2023"
  architectures = ["x86_64"]
  timeout       = 30
  memory_size   = 256

  filename         = var.lambda_source_type == "local" ? "${path.module}/../lambda/target/api_list_classifications.zip" : null
  s3_bucket        = var.lambda_source_type == "s3" ? var.lambda_artifacts_bucket_name : null
  s3_key           = var.lambda_source_type == "s3" ? "builds/${var.lambda_build_tag}/api_list_classifications.zip" : null
  source_code_hash = var.lambda_source_type == "local" ? filebase64sha256("${path.module}/../lambda/target/api_list_classifications.zip") : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-list-classifications"
  })
}

# List Summaries Lambda
resource "aws_lambda_function" "api_list_summaries" {
  function_name = "${var.project_name}-api-list-summaries"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.handler"
  runtime       = "provided.al2023"
  architectures = ["x86_64"]
  timeout       = 30
  memory_size   = 256

  filename         = var.lambda_source_type == "local" ? "${path.module}/../lambda/target/api_list_summaries.zip" : null
  s3_bucket        = var.lambda_source_type == "s3" ? var.lambda_artifacts_bucket_name : null
  s3_key           = var.lambda_source_type == "s3" ? "builds/${var.lambda_build_tag}/api_list_summaries.zip" : null
  source_code_hash = var.lambda_source_type == "local" ? filebase64sha256("${path.module}/../lambda/target/api_list_summaries.zip") : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-list-summaries"
  })
}

# List Reports Lambda
resource "aws_lambda_function" "api_list_reports" {
  function_name = "${var.project_name}-api-list-reports"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.handler"
  runtime       = "provided.al2023"
  architectures = ["x86_64"]
  timeout       = 30
  memory_size   = 256

  filename         = var.lambda_source_type == "local" ? "${path.module}/../lambda/target/api_list_reports.zip" : null
  s3_bucket        = var.lambda_source_type == "s3" ? var.lambda_artifacts_bucket_name : null
  s3_key           = var.lambda_source_type == "s3" ? "builds/${var.lambda_build_tag}/api_list_reports.zip" : null
  source_code_hash = var.lambda_source_type == "local" ? filebase64sha256("${path.module}/../lambda/target/api_list_reports.zip") : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-list-reports"
  })
}

# =============================================================================
# CloudWatch Log Groups for API Lambdas
# =============================================================================

resource "aws_cloudwatch_log_group" "api_lambdas" {
  for_each = toset(local.api_lambda_functions)

  name              = "/aws/lambda/${var.project_name}-${replace(each.key, "_", "-")}"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${replace(each.key, "_", "-")}-logs"
  })
}
```

### 1.3.2 Shared API Response Utilities

**File**: `lambda/shared/api/response.clj`

```clojure
(ns api.response
  "Utilities for API Gateway Lambda responses"
  (:require [cheshire.core :as json]))

(defn ok
  "Create a 200 OK response"
  [body]
  {:statusCode 200
   :headers {"Content-Type" "application/json"
             "Cache-Control" "private, max-age=60"}
   :body (json/generate-string body)})

(defn ok-no-cache
  "Create a 200 OK response with no caching"
  [body]
  {:statusCode 200
   :headers {"Content-Type" "application/json"
             "Cache-Control" "no-cache, no-store, must-revalidate"}
   :body (json/generate-string body)})

(defn bad-request
  "Create a 400 Bad Request response"
  [message]
  {:statusCode 400
   :headers {"Content-Type" "application/json"}
   :body (json/generate-string {:error "Bad Request"
                                :message message})})

(defn not-found
  "Create a 404 Not Found response"
  [message]
  {:statusCode 404
   :headers {"Content-Type" "application/json"}
   :body (json/generate-string {:error "Not Found"
                                :message message})})

(defn internal-error
  "Create a 500 Internal Server Error response"
  [message]
  {:statusCode 500
   :headers {"Content-Type" "application/json"}
   :body (json/generate-string {:error "Internal Server Error"
                                :message message})})

(defn parse-query-params
  "Parse query parameters from API Gateway event"
  [event]
  (or (get event "queryStringParameters") {}))

(defn parse-path-params
  "Parse path parameters from API Gateway event"
  [event]
  (or (get event "pathParameters") {}))

(defn parse-int-param
  "Parse integer parameter with default"
  [params key default-val]
  (if-let [val (get params key)]
    (try (Integer/parseInt val)
         (catch NumberFormatException _ default-val))
    default-val))

(defn get-user-sub
  "Extract user sub (Cognito user ID) from JWT claims"
  [event]
  (get-in event ["requestContext" "authorizer" "jwt" "claims" "sub"]))
```

### 1.3.3 API Lambda Handler: List Documents

**File**: `lambda/functions/api_list_documents/handler.clj`

```clojure
(ns handler
  "API Lambda: List documents with pagination and filtering"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def default-limit 50)
(def max-limit 100)

(defn list-documents
  "Query documents with optional classification filter"
  [{:keys [classification limit cursor]}]
  (let [limit (min limit max-limit)]
    (if classification
      ;; Query by classification using GSI
      (ddb/query ddb-table
                 :index-name "classification-index"
                 :key-condition-expr "classification = :class"
                 :expr-attr-values {":class" classification}
                 :limit limit)
      ;; Scan all metadata items
      (ddb/scan ddb-table
                :filter-expr "SK = :sk"
                :expr-attr-values {":sk" "METADATA"}
                :limit limit))))

(defn format-document
  "Format document metadata for API response"
  [doc]
  {:id (:PK doc)
   :title (or (:title doc) "Untitled")
   :classification (:classification doc)
   :tags (or (:tags doc) [])
   :linksTo (or (:links_to doc) [])
   :entities (:entities doc)
   :created (:created doc)
   :modified (:modified doc)
   :hasFrontmatter (:has_frontmatter doc)})

(defn handler
  "Lambda handler for GET /documents"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          params (r/parse-query-params event)
          classification (get params "classification")
          limit (r/parse-int-param params "limit" default-limit)
          cursor (get params "cursor")
          user-sub (r/get-user-sub event)

          _ (println "User" user-sub "listing documents, classification:" classification)

          documents (list-documents {:classification classification
                                     :limit limit
                                     :cursor cursor})
          formatted (mapv format-document documents)]

      (r/ok {:documents formatted
             :count (count formatted)
             :nextCursor nil}))  ; TODO: implement cursor-based pagination

    (catch Exception e
      (println "Error listing documents:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to list documents"))))
```

### 1.3.4 API Lambda Handler: Get Document

**File**: `lambda/functions/api_get_document/handler.clj`

```clojure
(ns handler
  "API Lambda: Get single document with content"
  (:require [aws.dynamodb :as ddb]
            [aws.s3 :as s3]
            [api.response :as r]
            [cheshire.core :as json]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn get-document-metadata
  "Get document metadata from DynamoDB"
  [document-key]
  (ddb/get-item ddb-table {:PK document-key :SK "METADATA"}))

(defn get-document-content
  "Get document content from S3"
  [document-key]
  (try
    (s3/get-object s3-bucket document-key)
    (catch Exception e
      (println "Error fetching content for" document-key ":" (.getMessage e))
      nil)))

(defn format-document-detail
  "Format full document with content for API response"
  [metadata content]
  {:id (:PK metadata)
   :title (or (:title metadata) "Untitled")
   :content content
   :classification (:classification metadata)
   :tags (or (:tags metadata) [])
   :linksTo (or (:links_to metadata) [])
   :entities (:entities metadata)
   :created (:created metadata)
   :modified (:modified metadata)
   :hasFrontmatter (:has_frontmatter metadata)})

(defn handler
  "Lambda handler for GET /documents/{key+}"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          path-params (r/parse-path-params event)
          document-key (get path-params "key")
          user-sub (r/get-user-sub event)]

      (when-not document-key
        (throw (ex-info "Missing document key" {:type :bad-request})))

      (println "User" user-sub "fetching document:" document-key)

      (let [metadata (get-document-metadata document-key)]
        (if-not metadata
          (r/not-found (str "Document not found: " document-key))

          (let [content (get-document-content document-key)
                document (format-document-detail metadata content)]
            (r/ok document)))))

    (catch clojure.lang.ExceptionInfo e
      (let [data (ex-data e)]
        (case (:type data)
          :bad-request (r/bad-request (.getMessage e))
          (do
            (println "Error:" (.getMessage e))
            (r/internal-error "Failed to get document")))))

    (catch Exception e
      (println "Error getting document:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to get document"))))
```

### 1.3.5 API Lambda Handler: Search

**File**: `lambda/functions/api_search/handler.clj`

```clojure
(ns handler
  "API Lambda: Search documents by query"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def default-limit 20)
(def max-limit 50)

(defn search-documents
  "Search documents by title and tags (basic implementation)"
  [query limit]
  (let [query-lower (str/lower-case query)
        ;; Scan all metadata and filter client-side
        ;; TODO: Implement OpenSearch for better search
        all-docs (ddb/scan ddb-table
                           :filter-expr "SK = :sk"
                           :expr-attr-values {":sk" "METADATA"}
                           :limit 500)]
    (->> all-docs
         (filter (fn [doc]
                   (let [title (str/lower-case (or (:title doc) ""))
                         tags (or (:tags doc) [])]
                     (or (str/includes? title query-lower)
                         (some #(str/includes? (str/lower-case %) query-lower) tags)))))
         (take limit)
         (vec))))

(defn format-search-result
  "Format document for search results"
  [doc]
  {:id (:PK doc)
   :title (or (:title doc) "Untitled")
   :classification (:classification doc)
   :tags (or (:tags doc) [])
   :modified (:modified doc)})

(defn handler
  "Lambda handler for GET /search?q=..."
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          params (r/parse-query-params event)
          query (get params "q")
          limit (r/parse-int-param params "limit" default-limit)
          user-sub (r/get-user-sub event)]

      (when (or (nil? query) (str/blank? query))
        (throw (ex-info "Query parameter 'q' is required" {:type :bad-request})))

      (when (< (count query) 2)
        (throw (ex-info "Query must be at least 2 characters" {:type :bad-request})))

      (println "User" user-sub "searching for:" query)

      (let [limit (min limit max-limit)
            results (search-documents query limit)
            formatted (mapv format-search-result results)]

        (r/ok {:query query
               :results formatted
               :count (count formatted)})))

    (catch clojure.lang.ExceptionInfo e
      (let [data (ex-data e)]
        (case (:type data)
          :bad-request (r/bad-request (.getMessage e))
          (do
            (println "Error:" (.getMessage e))
            (r/internal-error "Search failed")))))

    (catch Exception e
      (println "Error searching:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Search failed"))))
```

### 1.3.6 API Lambda Handler: List Tags

**File**: `lambda/functions/api_list_tags/handler.clj`

```clojure
(ns handler
  "API Lambda: List all unique tags with document counts"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))

(defn get-all-tags
  "Get all unique tags with document counts"
  []
  ;; Query all tag# entries
  (let [results (ddb/scan ddb-table
                          :filter-expr "begins_with(PK, :prefix)"
                          :expr-attr-values {":prefix" "tag#"}
                          :limit 1000)]
    ;; Group by tag name and count
    (->> results
         (group-by :tag_name)
         (map (fn [[tag-name docs]]
                {:name tag-name
                 :count (count docs)}))
         (sort-by :name)
         (vec))))

(defn handler
  "Lambda handler for GET /tags"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)

          _ (println "User" user-sub "listing tags")

          tags (get-all-tags)]

      (r/ok {:tags tags
             :count (count tags)}))

    (catch Exception e
      (println "Error listing tags:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to list tags"))))
```

### 1.3.7 API Lambda Handler: Documents by Tag

**File**: `lambda/functions/api_documents_by_tag/handler.clj`

```clojure
(ns handler
  "API Lambda: Get documents by tag"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def default-limit 50)

(defn get-documents-by-tag
  "Get all documents with a specific tag"
  [tag limit]
  (ddb/query ddb-table
             :key-condition-expr "PK = :pk"
             :expr-attr-values {":pk" (str "tag#" tag)}
             :limit limit))

(defn get-document-metadata
  "Get full metadata for a document"
  [doc-path]
  (ddb/get-item ddb-table {:PK doc-path :SK "METADATA"}))

(defn format-document
  "Format document for response"
  [doc metadata]
  {:id (:document_path doc)
   :title (or (:title metadata) "Untitled")
   :classification (:classification metadata)
   :tags (or (:tags metadata) [])
   :modified (:modified metadata)})

(defn handler
  "Lambda handler for GET /tags/{tag}/documents"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          path-params (r/parse-path-params event)
          tag (get path-params "tag")
          params (r/parse-query-params event)
          limit (r/parse-int-param params "limit" default-limit)
          user-sub (r/get-user-sub event)]

      (when-not tag
        (throw (ex-info "Missing tag parameter" {:type :bad-request})))

      (println "User" user-sub "getting documents for tag:" tag)

      (let [tag-docs (get-documents-by-tag tag limit)
            documents (for [doc tag-docs
                           :let [metadata (get-document-metadata (:document_path doc))]
                           :when metadata]
                       (format-document doc metadata))]

        (r/ok {:tag tag
               :documents (vec documents)
               :count (count documents)})))

    (catch clojure.lang.ExceptionInfo e
      (let [data (ex-data e)]
        (case (:type data)
          :bad-request (r/bad-request (.getMessage e))
          (do
            (println "Error:" (.getMessage e))
            (r/internal-error "Failed to get documents by tag")))))

    (catch Exception e
      (println "Error getting documents by tag:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to get documents by tag"))))
```

### 1.3.8 API Lambda Handler: List Classifications

**File**: `lambda/functions/api_list_classifications/handler.clj`

```clojure
(ns handler
  "API Lambda: List document counts by classification"
  (:require [aws.dynamodb :as ddb]
            [api.response :as r]
            [cheshire.core :as json]))

(def ddb-table (System/getenv "DYNAMODB_TABLE_NAME"))
(def classifications ["meeting" "idea" "reference" "journal" "project"])

(defn count-by-classification
  "Count documents for each classification"
  []
  (for [class classifications]
    (let [docs (ddb/query ddb-table
                          :index-name "classification-index"
                          :key-condition-expr "classification = :class"
                          :expr-attr-values {":class" class}
                          :limit 1000)]
      {:name class
       :displayName (clojure.string/capitalize class)
       :count (count docs)
       :icon (case class
               "meeting" "person.3"
               "idea" "lightbulb"
               "reference" "book"
               "journal" "book.closed"
               "project" "folder"
               "doc")})))

(defn handler
  "Lambda handler for GET /classifications"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          user-sub (r/get-user-sub event)

          _ (println "User" user-sub "listing classifications")

          classifications (vec (count-by-classification))]

      (r/ok {:classifications classifications}))

    (catch Exception e
      (println "Error listing classifications:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to list classifications"))))
```

### 1.3.9 API Lambda Handler: List Summaries

**File**: `lambda/functions/api_list_summaries/handler.clj`

```clojure
(ns handler
  "API Lambda: List daily summaries from _agent directory"
  (:require [aws.s3 :as s3]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def summaries-prefix "_agent/summaries/daily/")
(def default-limit 30)

(defn list-summaries
  "List daily summary files from S3"
  [limit]
  (let [objects (s3/list-objects s3-bucket summaries-prefix)]
    (->> objects
         (filter #(str/ends-with? (:key %) ".md"))
         (sort-by :last-modified #(compare %2 %1))  ; Most recent first
         (take limit)
         (map (fn [obj]
                (let [key (:key obj)
                      filename (last (str/split key #"/"))
                      date (str/replace filename ".md" "")]
                  {:id key
                   :date date
                   :modified (:last-modified obj)})))
         (vec))))

(defn handler
  "Lambda handler for GET /summaries"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          params (r/parse-query-params event)
          limit (r/parse-int-param params "limit" default-limit)
          user-sub (r/get-user-sub event)

          _ (println "User" user-sub "listing summaries")

          summaries (list-summaries limit)]

      (r/ok {:summaries summaries
             :count (count summaries)}))

    (catch Exception e
      (println "Error listing summaries:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to list summaries"))))
```

### 1.3.10 API Lambda Handler: List Reports

**File**: `lambda/functions/api_list_reports/handler.clj`

```clojure
(ns handler
  "API Lambda: List weekly reports from _agent directory"
  (:require [aws.s3 :as s3]
            [api.response :as r]
            [cheshire.core :as json]
            [clojure.string :as str]))

(def s3-bucket (System/getenv "S3_BUCKET_NAME"))
(def reports-prefix "_agent/reports/weekly/")
(def default-limit 12)

(defn list-reports
  "List weekly report files from S3"
  [limit]
  (let [objects (s3/list-objects s3-bucket reports-prefix)]
    (->> objects
         (filter #(str/ends-with? (:key %) ".md"))
         (sort-by :last-modified #(compare %2 %1))  ; Most recent first
         (take limit)
         (map (fn [obj]
                (let [key (:key obj)
                      filename (last (str/split key #"/"))
                      week-date (str/replace filename ".md" "")]
                  {:id key
                   :weekOf week-date
                   :modified (:last-modified obj)})))
         (vec))))

(defn handler
  "Lambda handler for GET /reports"
  [request]
  (try
    (let [event (json/parse-string (:body request) true)
          params (r/parse-query-params event)
          limit (r/parse-int-param params "limit" default-limit)
          user-sub (r/get-user-sub event)

          _ (println "User" user-sub "listing reports")

          reports (list-reports limit)]

      (r/ok {:reports reports
             :count (count reports)}))

    (catch Exception e
      (println "Error listing reports:" (.getMessage e))
      (.printStackTrace e)
      (r/internal-error "Failed to list reports"))))
```

---

## 1.4 DynamoDB Index Updates

The existing DynamoDB table already has the required indexes:

- `classification-index`: GSI for querying by document classification
- `tag-index`: GSI for querying documents by tag
- `entity-index`: GSI for querying by entity

No additional indexes are required for Phase 1.

---

## 1.5 Integration Testing

### 1.5.1 API Test Script

**File**: `scripts/test-api.sh`

```bash
#!/bin/bash
# Integration tests for PKM Mobile API
# Usage: ./scripts/test-api.sh

set -e

# Get API URL and auth from Terraform outputs
API_URL=$(cd terraform && terraform output -raw api_gateway_url)
USER_POOL_ID=$(cd terraform && terraform output -raw cognito_user_pool_id)
CLIENT_ID=$(cd terraform && terraform output -raw cognito_client_id)

# These should be set as environment variables
: "${TEST_USER_EMAIL:?Need to set TEST_USER_EMAIL}"
: "${TEST_USER_PASSWORD:?Need to set TEST_USER_PASSWORD}"

echo "Testing API at: $API_URL"
echo ""

# Get auth token
echo "Authenticating..."
AUTH_RESULT=$(aws cognito-idp initiate-auth \
    --client-id "$CLIENT_ID" \
    --auth-flow USER_PASSWORD_AUTH \
    --auth-parameters USERNAME="$TEST_USER_EMAIL",PASSWORD="$TEST_USER_PASSWORD")

ACCESS_TOKEN=$(echo "$AUTH_RESULT" | jq -r '.AuthenticationResult.AccessToken')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo "Authentication failed"
    exit 1
fi

echo "Authentication successful"
echo ""

# Test endpoints
test_endpoint() {
    local name="$1"
    local path="$2"

    echo "Testing: $name"
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        "$API_URL$path")

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | head -n -1)

    if [ "$HTTP_CODE" = "200" ]; then
        echo "  ✓ Status: $HTTP_CODE"
        echo "  Response: $(echo "$BODY" | jq -c '.' | head -c 200)..."
    else
        echo "  ✗ Status: $HTTP_CODE"
        echo "  Error: $BODY"
        return 1
    fi
    echo ""
}

# Run tests
test_endpoint "List Documents" "/documents"
test_endpoint "List Documents (filtered)" "/documents?classification=meeting&limit=5"
test_endpoint "List Tags" "/tags"
test_endpoint "List Classifications" "/classifications"
test_endpoint "List Summaries" "/summaries?limit=5"
test_endpoint "List Reports" "/reports?limit=5"
test_endpoint "Search" "/search?q=meeting"

echo "All tests passed!"
```

### 1.5.2 Unit Tests for Lambda Functions

**File**: `lambda/tests/api_list_documents_test.clj`

```clojure
(ns api-list-documents-test
  (:require [clojure.test :refer :all]
            [handler :as h]))

;; Mock DynamoDB responses
(def mock-documents
  [{:PK "notes/test.md"
    :SK "METADATA"
    :title "Test Document"
    :classification "reference"
    :tags ["test" "example"]
    :modified "2026-01-15T10:00:00Z"}
   {:PK "meetings/weekly.md"
    :SK "METADATA"
    :title "Weekly Meeting"
    :classification "meeting"
    :tags ["meeting"]
    :modified "2026-01-14T09:00:00Z"}])

(deftest test-format-document
  (testing "formats document correctly"
    (let [doc (first mock-documents)
          formatted (h/format-document doc)]
      (is (= "notes/test.md" (:id formatted)))
      (is (= "Test Document" (:title formatted)))
      (is (= "reference" (:classification formatted)))
      (is (= ["test" "example"] (:tags formatted))))))

(deftest test-format-document-missing-title
  (testing "uses 'Untitled' for missing title"
    (let [doc (dissoc (first mock-documents) :title)
          formatted (h/format-document doc)]
      (is (= "Untitled" (:title formatted))))))
```

---

## Deliverables Checklist

### Infrastructure

| Item | File | Status |
|------|------|--------|
| Cognito User Pool | `terraform/cognito.tf` | Pending |
| Cognito App Client | `terraform/cognito.tf` | Pending |
| Cognito Identity Pool | `terraform/cognito.tf` | Pending |
| API Gateway HTTP API | `terraform/api_gateway.tf` | Pending |
| JWT Authorizer | `terraform/api_gateway.tf` | Pending |
| API Routes (8 endpoints) | `terraform/api_gateway.tf` | Pending |
| API Lambda Functions (8) | `terraform/api_lambda.tf` | Pending |
| CloudWatch Log Groups | `terraform/api_lambda.tf` | Pending |

### Lambda Functions

| Function | Purpose | Status |
|----------|---------|--------|
| `api_list_documents` | List documents with filters | Pending |
| `api_get_document` | Get single document | Pending |
| `api_search` | Search documents | Pending |
| `api_list_tags` | List all tags | Pending |
| `api_documents_by_tag` | Get documents by tag | Pending |
| `api_list_classifications` | List classification counts | Pending |
| `api_list_summaries` | List daily summaries | Pending |
| `api_list_reports` | List weekly reports | Pending |

### Shared Code

| Module | Purpose | Status |
|--------|---------|--------|
| `api/response.clj` | API response utilities | Pending |

### Testing

| Item | Status |
|------|--------|
| Unit tests for Lambda functions | Pending |
| Integration test script | Pending |
| Manual API testing | Pending |

### Documentation

| Item | Status |
|------|--------|
| API endpoint documentation | Pending |
| Cognito setup guide | Pending |

---

## CI/CD Integration

### Update Build Script

The `lambda/build.clj` script needs to be updated to include the new API Lambda functions:

```clojure
;; Add to lambda/build.clj
(def api-functions
  ["api_list_documents"
   "api_get_document"
   "api_search"
   "api_list_tags"
   "api_documents_by_tag"
   "api_list_classifications"
   "api_list_summaries"
   "api_list_reports"])
```

### GitHub Actions Updates

Add API Lambda functions to the existing build and deploy workflows.

---

## Implementation Order

1. **Week 1: Cognito & API Gateway**
   - Create `terraform/cognito.tf`
   - Create `terraform/api_gateway.tf`
   - Add variables and outputs
   - Deploy and verify Cognito setup

2. **Week 2: Core Lambda Functions**
   - Create shared `api/response.clj`
   - Implement `api_list_documents`
   - Implement `api_get_document`
   - Implement `api_search`
   - Update build script

3. **Week 3: Remaining Lambda Functions**
   - Implement `api_list_tags`
   - Implement `api_documents_by_tag`
   - Implement `api_list_classifications`
   - Implement `api_list_summaries`
   - Implement `api_list_reports`

4. **Week 4: Testing & Documentation**
   - Write unit tests
   - Create integration test script
   - Manual testing
   - API documentation

---

## Exit Criteria

Phase 1 is complete when:

- [ ] Cognito User Pool is deployed and accessible
- [ ] At least one test user can authenticate
- [ ] All 8 API endpoints are deployed and responding
- [ ] JWT authentication is working on all endpoints
- [ ] All Lambda functions pass unit tests
- [ ] Integration test script passes
- [ ] API Gateway logs show successful requests
- [ ] Documentation is complete

---

## Next Steps (Phase 2)

After Phase 1 completion, Phase 2 (iOS App Scaffold) can begin with:

- iOS project setup with Swift/SwiftUI
- AWS Amplify integration for Cognito
- APIClient implementation
- Document list and detail views
