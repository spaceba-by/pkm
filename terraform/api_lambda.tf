# =============================================================================
# API Lambda Functions for Mobile API
# =============================================================================

locals {
  api_lambda_functions = var.enable_mobile_api ? [
    "api-list-documents",
    "api-get-document",
    "api-search",
    "api-list-tags",
    "api-documents-by-tag",
    "api-list-classifications",
    "api-list-summaries",
    "api-list-reports"
  ] : []

  api_lambda_environment = {
    S3_BUCKET_NAME      = aws_s3_bucket.vault.id
    DYNAMODB_TABLE_NAME = aws_dynamodb_table.metadata.name
  }
}

# CloudWatch log groups for API Lambda functions
resource "aws_cloudwatch_log_group" "api_lambda_logs" {
  for_each = toset(local.api_lambda_functions)

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}"
  })
}

# =============================================================================
# API List Documents Lambda
# =============================================================================

resource "aws_lambda_function" "api_list_documents" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-list-documents"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  # Local source (default)
  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_list_documents.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_list_documents.zip") : null

  # S3 source (CI/CD)
  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_list_documents.zip" : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.api_lambda_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-list-documents"
  })
}

# =============================================================================
# API Get Document Lambda
# =============================================================================

resource "aws_lambda_function" "api_get_document" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-get-document"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  # Local source (default)
  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_get_document.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_get_document.zip") : null

  # S3 source (CI/CD)
  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_get_document.zip" : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.api_lambda_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-get-document"
  })
}

# =============================================================================
# API Search Lambda
# =============================================================================

resource "aws_lambda_function" "api_search" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-search"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  # Local source (default)
  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_search.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_search.zip") : null

  # S3 source (CI/CD)
  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_search.zip" : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.api_lambda_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-search"
  })
}

# =============================================================================
# API List Tags Lambda
# =============================================================================

resource "aws_lambda_function" "api_list_tags" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-list-tags"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  # Local source (default)
  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_list_tags.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_list_tags.zip") : null

  # S3 source (CI/CD)
  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_list_tags.zip" : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.api_lambda_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-list-tags"
  })
}

# =============================================================================
# API Documents By Tag Lambda
# =============================================================================

resource "aws_lambda_function" "api_documents_by_tag" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-documents-by-tag"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  # Local source (default)
  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_documents_by_tag.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_documents_by_tag.zip") : null

  # S3 source (CI/CD)
  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_documents_by_tag.zip" : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.api_lambda_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-documents-by-tag"
  })
}

# =============================================================================
# API List Classifications Lambda
# =============================================================================

resource "aws_lambda_function" "api_list_classifications" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-list-classifications"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  # Local source (default)
  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_list_classifications.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_list_classifications.zip") : null

  # S3 source (CI/CD)
  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_list_classifications.zip" : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.api_lambda_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-list-classifications"
  })
}

# =============================================================================
# API List Summaries Lambda
# =============================================================================

resource "aws_lambda_function" "api_list_summaries" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-list-summaries"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  # Local source (default)
  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_list_summaries.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_list_summaries.zip") : null

  # S3 source (CI/CD)
  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_list_summaries.zip" : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.api_lambda_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-list-summaries"
  })
}

# =============================================================================
# API List Reports Lambda
# =============================================================================

resource "aws_lambda_function" "api_list_reports" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-list-reports"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  # Local source (default)
  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_list_reports.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_list_reports.zip") : null

  # S3 source (CI/CD)
  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_list_reports.zip" : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.api_lambda_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-list-reports"
  })
}
