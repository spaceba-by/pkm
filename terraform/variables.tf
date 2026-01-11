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

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for PKM vault (must be globally unique)"
  type        = string
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
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "bedrock_sonnet_model_id" {
  description = "Bedrock model ID for Sonnet (summaries, reports)"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
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
