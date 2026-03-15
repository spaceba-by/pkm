# =============================================================================
# Task Extraction Infrastructure
# Processing Lambda, API Lambdas, EventBridge target, API Gateway routes
# =============================================================================

# =============================================================================
# Processing Lambda: extract-tasks
# =============================================================================

resource "aws_lambda_function" "extract_tasks" {
  function_name = "${var.project_name}-extract-tasks"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 512

  # Local source (default)
  filename         = local.use_local_source ? "${path.module}/../lambda/target/extract_tasks.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/extract_tasks.zip") : null

  # S3 source (CI/CD)
  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/extract_tasks.zip" : null

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

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = {
    Name = "${var.project_name}-extract-tasks"
  }
}

# =============================================================================
# EventBridge Target: extract-tasks (parallel with classify, extract_entities, extract_metadata)
# =============================================================================

resource "aws_cloudwatch_event_target" "extract_tasks" {
  rule      = aws_cloudwatch_event_rule.s3_markdown_events_exclude_agent.name
  target_id = "extract-tasks"
  arn       = aws_lambda_function.extract_tasks.arn
}

resource "aws_lambda_permission" "allow_eventbridge_extract_tasks" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.extract_tasks.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_markdown_events_exclude_agent.arn
}

# =============================================================================
# API Lambda: api-tasks (list tasks)
# =============================================================================

resource "aws_lambda_function" "api_tasks" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-tasks"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_tasks.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_tasks.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_tasks.zip" : null

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

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-tasks"
  })
}

# =============================================================================
# API Lambda: api-tasks-stats (task counts)
# =============================================================================

resource "aws_lambda_function" "api_tasks_stats" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-tasks-stats"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_tasks_stats.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_tasks_stats.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_tasks_stats.zip" : null

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

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-tasks-stats"
  })
}

# =============================================================================
# API Gateway Routes - Tasks
# =============================================================================

# GET /tasks - List tasks with filtering
resource "aws_apigatewayv2_integration" "list_tasks" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_tasks["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_tasks" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /tasks"
  target             = "integrations/${aws_apigatewayv2_integration.list_tasks["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

resource "aws_lambda_permission" "api_tasks" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_tasks["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

# GET /tasks/stats - Task counts
resource "aws_apigatewayv2_integration" "tasks_stats" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_tasks_stats["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "tasks_stats" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /tasks/stats"
  target             = "integrations/${aws_apigatewayv2_integration.tasks_stats["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

resource "aws_lambda_permission" "api_tasks_stats" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_tasks_stats["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}
