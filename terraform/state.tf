# Terraform State Management Infrastructure
#
# This file creates the S3 bucket and DynamoDB table needed for remote
# state management. These resources must be created before enabling the
# S3 backend in main.tf.
#
# Bootstrap process:
# 1. First apply with enable_terraform_state_resources = true (creates bucket/table)
# 2. Then uncomment the backend "s3" block in main.tf
# 3. Run `terraform init -migrate-state` to migrate local state to S3

variable "enable_terraform_state_resources" {
  description = "Enable creation of Terraform state S3 bucket and DynamoDB lock table"
  type        = bool
  default     = false
}

variable "terraform_state_bucket_name" {
  description = "S3 bucket name for Terraform state. Required when enable_terraform_state_resources is true."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_terraform_state_resources || var.terraform_state_bucket_name != ""
    error_message = "terraform_state_bucket_name is required when enable_terraform_state_resources is true."
  }
}

locals {
  terraform_state = var.enable_terraform_state_resources ? { "enabled" = true } : {}
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  for_each = local.terraform_state

  bucket = var.terraform_state_bucket_name

  # Prevent accidental deletion of state bucket
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, {
    Name    = var.terraform_state_bucket_name
    Purpose = "Terraform state storage"
  })
}

# Enable versioning for state history and recovery
resource "aws_s3_bucket_versioning" "terraform_state" {
  for_each = local.terraform_state

  bucket = aws_s3_bucket.terraform_state["enabled"].id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  for_each = local.terraform_state

  bucket = aws_s3_bucket.terraform_state["enabled"].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  for_each = local.terraform_state

  bucket = aws_s3_bucket.terraform_state["enabled"].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  for_each = local.terraform_state

  name         = "${var.project_name}-terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-terraform-state-lock"
    Purpose = "Terraform state locking"
  })
}

# Outputs for backend configuration
output "terraform_state_bucket_name" {
  description = "S3 bucket name for Terraform state (use in backend config)"
  value       = var.enable_terraform_state_resources ? aws_s3_bucket.terraform_state["enabled"].id : null
}

output "terraform_state_lock_table_name" {
  description = "DynamoDB table name for state locking (use in backend config)"
  value       = var.enable_terraform_state_resources ? aws_dynamodb_table.terraform_state_lock["enabled"].name : null
}

output "terraform_backend_config" {
  description = "Backend configuration snippet for main.tf"
  value = var.enable_terraform_state_resources ? join("\n", [
    "# Add this to the terraform {} block in main.tf:",
    "backend \"s3\" {",
    "  bucket         = ${aws_s3_bucket.terraform_state[\"enabled\"].id}",
    "  key            = \"pkm-agent/terraform.tfstate\"",
    "  region         = ${var.aws_region}",
    "  encrypt        = true",
    "  dynamodb_table = ${aws_dynamodb_table.terraform_state_lock[\"enabled\"].name}",
    "}"
  ]) : null
}
