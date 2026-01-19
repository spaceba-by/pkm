# S3 bucket for Lambda build artifacts (CI/CD)
resource "aws_s3_bucket" "lambda_artifacts" {
  count  = var.lambda_artifacts_bucket_name != "" ? 1 : 0
  bucket = var.lambda_artifacts_bucket_name

  tags = merge(var.tags, {
    Name = var.lambda_artifacts_bucket_name
  })
}

# Enable versioning for artifact history
resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  count  = var.lambda_artifacts_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.lambda_artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_artifacts" {
  count  = var.lambda_artifacts_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.lambda_artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "lambda_artifacts" {
  count  = var.lambda_artifacts_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.lambda_artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule to expire old builds after 90 days
resource "aws_s3_bucket_lifecycle_configuration" "lambda_artifacts" {
  count  = var.lambda_artifacts_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.lambda_artifacts[0].id

  rule {
    id     = "expire-old-builds"
    status = "Enabled"

    filter {
      prefix = "builds/"
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
