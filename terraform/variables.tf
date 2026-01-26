variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "pkm-agent"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for PKM vault (must be globally unique)"
  type        = string
  default     = "notes.spaceba.by"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for metadata"
  type        = string
  default     = "pkm-metadata"
}

variable "enable_s3_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "daily_summary_schedule" {
  description = "Cron schedule for daily summary (UTC)"
  type        = string
  default     = "cron(0 6 * * ? *)"
}

variable "weekly_report_schedule" {
  description = "Cron schedule for weekly report (UTC)"
  type        = string
  default     = "cron(0 20 ? * SUN *)"
}

variable "bedrock_haiku_model_id" {
  description = "Bedrock model ID for Haiku (classification, extraction)"
  type        = string
  default     = "global.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "bedrock_sonnet_model_id" {
  description = "Bedrock model ID for Sonnet (summaries, reports)"
  type        = string
  default     = "global.anthropic.claude-sonnet-4-5-20250929-v1:0"
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for Lambda and Step Functions"
  type        = bool
  default     = true
}

variable "lambda_log_retention_days" {
  description = "CloudWatch log retention in days for Lambda functions"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "PKM Agent System"
    ManagedBy = "Terraform"
  }
}

# CI/CD Variables

variable "enable_github_oidc" {
  description = "Enable GitHub Actions OIDC authentication for CI/CD"
  type        = bool
  default     = true
}

variable "enable_lambda_artifacts_bucket" {
  description = "Enable S3 bucket for Lambda build artifacts"
  type        = bool
  default     = true
}

variable "lambda_artifacts_bucket_name" {
  description = "S3 bucket name for Lambda build artifacts. Required when enable_lambda_artifacts_bucket is true."
  type        = string
  default     = "pkm-artifacts"

  validation {
    condition     = !var.enable_lambda_artifacts_bucket || var.lambda_artifacts_bucket_name != ""
    error_message = "lambda_artifacts_bucket_name is required when enable_lambda_artifacts_bucket is true."
  }
}

variable "lambda_build_tag" {
  description = "Build tag for S3 deployment (e.g., main-abc1234-20260119153045). Required when lambda_source_type is 's3'."
  type        = string
  default     = ""
}

variable "lambda_source_type" {
  description = "Source type for Lambda code: 'local' (from ../lambda/target/) or 's3' (from artifacts bucket)"
  type        = string
  default     = "local"

  validation {
    condition     = contains(["local", "s3"], var.lambda_source_type)
    error_message = "lambda_source_type must be either 'local' or 's3'."
  }
}

variable "github_repository" {
  description = "GitHub repository for OIDC authentication (e.g., 'owner/repo'). Required when enable_github_oidc is true."
  type        = string
  default     = "spaceba-by/pkm"

  validation {
    condition     = !var.enable_github_oidc || var.github_repository != ""
    error_message = "github_repository is required when enable_github_oidc is true."
  }
}
