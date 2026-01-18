# NOTE: Babashka binary is now bundled in each Lambda ZIP (via bblf uberjar approach)
# No separate layer needed

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

# 1. classify-document Lambda (Babashka)
resource "aws_lambda_function" "classify_document" {
  filename         = "${path.module}/../lambda-bb/target/classify_document.zip"
  function_name    = "${var.project_name}-classify-document"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler/handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda-bb/target/classify_document.zip")
  runtime          = "provided.al2023"
  timeout          = 30
  memory_size      = 512

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

# 2. extract-entities Lambda (Babashka)
resource "aws_lambda_function" "extract_entities" {
  filename         = "${path.module}/../lambda-bb/target/extract_entities.zip"
  function_name    = "${var.project_name}-extract-entities"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler/handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda-bb/target/extract_entities.zip")
  runtime          = "provided.al2023"
  timeout          = 30
  memory_size      = 512

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

# 3. extract-metadata Lambda (Babashka)
resource "aws_lambda_function" "extract_metadata" {
  filename         = "${path.module}/../lambda-bb/target/extract_metadata.zip"
  function_name    = "${var.project_name}-extract-metadata"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler/handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda-bb/target/extract_metadata.zip")
  runtime          = "provided.al2023"
  timeout          = 10
  memory_size      = 256

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

# 4. generate-daily-summary Lambda (Babashka)
resource "aws_lambda_function" "generate_daily_summary" {
  filename         = "${path.module}/../lambda-bb/target/generate_daily_summary.zip"
  function_name    = "${var.project_name}-generate-daily-summary"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler/handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda-bb/target/generate_daily_summary.zip")
  runtime          = "provided.al2023"
  timeout          = 60
  memory_size      = 1024

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

# 5. generate-weekly-report Lambda (Babashka)
resource "aws_lambda_function" "generate_weekly_report" {
  filename         = "${path.module}/../lambda-bb/target/generate_weekly_report.zip"
  function_name    = "${var.project_name}-generate-weekly-report"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler/handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda-bb/target/generate_weekly_report.zip")
  runtime          = "provided.al2023"
  timeout          = 120
  memory_size      = 2048

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

# 6. update-classification-index Lambda (Babashka)
resource "aws_lambda_function" "update_classification_index" {
  filename         = "${path.module}/../lambda-bb/target/update_classification_index.zip"
  function_name    = "${var.project_name}-update-classification-index"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "handler/handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda-bb/target/update_classification_index.zip")
  runtime          = "provided.al2023"
  timeout          = 30
  memory_size      = 256

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
