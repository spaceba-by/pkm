# Archive Lambda source code
data "archive_file" "lambda_shared" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/shared"
  output_path = "${path.module}/.terraform/lambda-shared.zip"
}

# Lambda layer for shared utilities
resource "aws_lambda_layer_version" "shared_utilities" {
  filename            = data.archive_file.lambda_shared.output_path
  layer_name          = "${var.project_name}-shared-utilities"
  source_code_hash    = data.archive_file.lambda_shared.output_base64sha256
  compatible_runtimes = ["python3.12"]

  description = "Shared utilities for PKM agent Lambda functions"
}

# CloudWatch log groups for Lambda functions
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = toset([
    "classify-document",
    "extract-entities",
    "extract-metadata",
    "generate-daily-summary",
    "generate-weekly-report",
    "update-classification-index"
  ])

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${var.project_name}-${each.key}"
  }
}

# Dead Letter Queue for failed Lambda invocations
resource "aws_sqs_queue" "lambda_dlq" {
  name                      = "${var.project_name}-lambda-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name = "${var.project_name}-lambda-dlq"
  }
}

# 1. classify-document Lambda
data "archive_file" "classify_document" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/classify_document"
  output_path = "${path.module}/.terraform/classify-document.zip"
}

resource "aws_lambda_function" "classify_document" {
  filename         = data.archive_file.classify_document.output_path
  function_name    = "${var.project_name}-classify-document"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.classify_document.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 512

  layers = [aws_lambda_layer_version.shared_utilities.arn]

  environment {
    variables = {
      S3_BUCKET_NAME       = aws_s3_bucket.vault.id
      DYNAMODB_TABLE_NAME  = aws_dynamodb_table.metadata.name
      BEDROCK_MODEL_ID     = var.bedrock_haiku_model_id
      UPDATE_INDEX_LAMBDA  = "${var.project_name}-update-classification-index"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = {
    Name = "${var.project_name}-classify-document"
  }
}

# 2. extract-entities Lambda
data "archive_file" "extract_entities" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/extract_entities"
  output_path = "${path.module}/.terraform/extract-entities.zip"
}

resource "aws_lambda_function" "extract_entities" {
  filename         = data.archive_file.extract_entities.output_path
  function_name    = "${var.project_name}-extract-entities"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.extract_entities.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 512

  layers = [aws_lambda_layer_version.shared_utilities.arn]

  environment {
    variables = {
      S3_BUCKET_NAME      = aws_s3_bucket.vault.id
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.metadata.name
      BEDROCK_MODEL_ID    = var.bedrock_haiku_model_id
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = {
    Name = "${var.project_name}-extract-entities"
  }
}

# 3. extract-metadata Lambda
data "archive_file" "extract_metadata" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/extract_metadata"
  output_path = "${path.module}/.terraform/extract-metadata.zip"
}

resource "aws_lambda_function" "extract_metadata" {
  filename         = data.archive_file.extract_metadata.output_path
  function_name    = "${var.project_name}-extract-metadata"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.extract_metadata.output_base64sha256
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 256

  layers = [aws_lambda_layer_version.shared_utilities.arn]

  environment {
    variables = {
      S3_BUCKET_NAME      = aws_s3_bucket.vault.id
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.metadata.name
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = {
    Name = "${var.project_name}-extract-metadata"
  }
}

# 4. generate-daily-summary Lambda
data "archive_file" "generate_daily_summary" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/generate_daily_summary"
  output_path = "${path.module}/.terraform/generate-daily-summary.zip"
}

resource "aws_lambda_function" "generate_daily_summary" {
  filename         = data.archive_file.generate_daily_summary.output_path
  function_name    = "${var.project_name}-generate-daily-summary"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.generate_daily_summary.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 1024

  layers = [aws_lambda_layer_version.shared_utilities.arn]

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
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = {
    Name = "${var.project_name}-generate-daily-summary"
  }
}

# 5. generate-weekly-report Lambda
data "archive_file" "generate_weekly_report" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/generate_weekly_report"
  output_path = "${path.module}/.terraform/generate-weekly-report.zip"
}

resource "aws_lambda_function" "generate_weekly_report" {
  filename         = data.archive_file.generate_weekly_report.output_path
  function_name    = "${var.project_name}-generate-weekly-report"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.generate_weekly_report.output_base64sha256
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 2048

  layers = [aws_lambda_layer_version.shared_utilities.arn]

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
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = {
    Name = "${var.project_name}-generate-weekly-report"
  }
}

# 6. update-classification-index Lambda
data "archive_file" "update_classification_index" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/update_classification_index"
  output_path = "${path.module}/.terraform/update-classification-index.zip"
}

resource "aws_lambda_function" "update_classification_index" {
  filename         = data.archive_file.update_classification_index.output_path
  function_name    = "${var.project_name}-update-classification-index"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.update_classification_index.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  layers = [aws_lambda_layer_version.shared_utilities.arn]

  environment {
    variables = {
      S3_BUCKET_NAME      = aws_s3_bucket.vault.id
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.metadata.name
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = {
    Name = "${var.project_name}-update-classification-index"
  }
}
