# =============================================================================
# Persistent Search Lambda Functions
# =============================================================================

# CloudWatch log groups for persistent search Lambda functions
resource "aws_cloudwatch_log_group" "persistent_search_logs" {
  for_each = toset([
    "persistent-search-execute",
    "persistent-search-summarize"
  ])

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${var.project_name}-${each.key}"
  }
}

# =============================================================================
# Persistent Search Execute Lambda
# =============================================================================

resource "aws_lambda_function" "persistent_search_execute" {
  function_name = "${var.project_name}-persistent-search-execute"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 120
  memory_size   = 512

  # Local source (default)
  filename         = local.use_local_source ? "${path.module}/../lambda/target/persistent_search_execute.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/persistent_search_execute.zip") : null

  # S3 source (CI/CD)
  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/persistent_search_execute.zip" : null

  environment {
    variables = {
      DYNAMODB_TABLE_NAME     = aws_dynamodb_table.metadata.name
      BRAVE_SEARCH_SECRET_ARN = aws_secretsmanager_secret.brave_search_api_key.arn
      SUMMARIZE_LAMBDA_NAME   = aws_lambda_function.persistent_search_summarize.function_name
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.persistent_search_logs
  ]

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = {
    Name = "${var.project_name}-persistent-search-execute"
  }
}

# =============================================================================
# Persistent Search Summarize Lambda
# =============================================================================

resource "aws_lambda_function" "persistent_search_summarize" {
  function_name = "${var.project_name}-persistent-search-summarize"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 120
  memory_size   = 1024

  # Local source (default)
  filename         = local.use_local_source ? "${path.module}/../lambda/target/persistent_search_summarize.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/persistent_search_summarize.zip") : null

  # S3 source (CI/CD)
  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/persistent_search_summarize.zip" : null

  environment {
    variables = {
      S3_BUCKET_NAME      = aws_s3_bucket.vault.id
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.metadata.name
      BEDROCK_MODEL_ID    = var.bedrock_sonnet_model_id
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.persistent_search_logs
  ]

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = {
    Name = "${var.project_name}-persistent-search-summarize"
  }
}
