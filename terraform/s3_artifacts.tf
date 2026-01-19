# S3 bucket for Lambda build artifacts (CI/CD)
resource "aws_s3_bucket" "lambda_artifacts" {
  for_each = local.lambda_artifacts
  bucket   = var.lambda_artifacts_bucket_name

  tags = merge(var.tags, {
    Name = var.lambda_artifacts_bucket_name
  })
}

# Enable versioning for artifact history
resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  for_each = local.lambda_artifacts
  bucket   = aws_s3_bucket.lambda_artifacts["enabled"].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_artifacts" {
  for_each = local.lambda_artifacts
  bucket   = aws_s3_bucket.lambda_artifacts["enabled"].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "lambda_artifacts" {
  for_each = local.lambda_artifacts
  bucket   = aws_s3_bucket.lambda_artifacts["enabled"].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule to expire builds tagged for deletion
# Objects are protected by default - only objects explicitly tagged with
# lifecycle=expire will be deleted. Use scripts/cleanup-old-builds.sh to
# mark old undeployed builds for deletion.
resource "aws_s3_bucket_lifecycle_configuration" "lambda_artifacts" {
  for_each = local.lambda_artifacts
  bucket   = aws_s3_bucket.lambda_artifacts["enabled"].id

  rule {
    id     = "expire-tagged-builds"
    status = "Enabled"

    filter {
      and {
        prefix = "builds/"
        tags = {
          lifecycle = "expire"
        }
      }
    }

    # Delete objects 7 days after being tagged for expiration
    # (gives time to undo if tagged by mistake)
    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
