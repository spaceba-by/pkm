# =============================================================================
# Persistent Search API Lambda Functions
# =============================================================================

locals {
  persistent_search_api_functions = var.enable_mobile_api ? [
    "api-search-monitors",
    "api-search-monitor-detail",
    "api-search-summaries"
  ] : []
}

# CloudWatch log groups for persistent search API Lambda functions
resource "aws_cloudwatch_log_group" "persistent_search_api_logs" {
  for_each = toset(local.persistent_search_api_functions)

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}"
  })
}

# =============================================================================
# API Search Monitors Lambda (POST/GET /searches, PUT/DELETE /searches/{id})
# =============================================================================

resource "aws_lambda_function" "api_search_monitors" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-search-monitors"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_search_monitors.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_search_monitors.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_search_monitors.zip" : null

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
    aws_cloudwatch_log_group.persistent_search_api_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-search-monitors"
  })
}

# =============================================================================
# API Search Monitor Detail Lambda (GET /searches/{id})
# =============================================================================

resource "aws_lambda_function" "api_search_monitor_detail" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-search-monitor-detail"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_search_monitor_detail.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_search_monitor_detail.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_search_monitor_detail.zip" : null

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
    aws_cloudwatch_log_group.persistent_search_api_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-search-monitor-detail"
  })
}

# =============================================================================
# API Search Summaries Lambda (GET /searches/{id}/summaries[/{timestamp}])
# =============================================================================

resource "aws_lambda_function" "api_search_summaries" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-search-summaries"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_search_summaries.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_search_summaries.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_search_summaries.zip" : null

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
    aws_cloudwatch_log_group.persistent_search_api_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-search-summaries"
  })
}

# =============================================================================
# API Gateway Routes - Persistent Search
# =============================================================================

# POST /searches - Create a new search monitor
resource "aws_apigatewayv2_integration" "create_search_monitor" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_search_monitors["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create_search_monitor" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "POST /searches"
  target             = "integrations/${aws_apigatewayv2_integration.create_search_monitor["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# GET /searches - List all search monitors
resource "aws_apigatewayv2_integration" "list_search_monitors" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_search_monitors["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_search_monitors" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /searches"
  target             = "integrations/${aws_apigatewayv2_integration.list_search_monitors["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# GET /searches/{id} - Get monitor details with recent summaries
resource "aws_apigatewayv2_integration" "get_search_monitor" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_search_monitor_detail["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_search_monitor" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /searches/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.get_search_monitor["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# PUT /searches/{id} - Update a search monitor
resource "aws_apigatewayv2_integration" "update_search_monitor" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_search_monitors["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "update_search_monitor" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "PUT /searches/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.update_search_monitor["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# DELETE /searches/{id} - Delete a search monitor
resource "aws_apigatewayv2_integration" "delete_search_monitor" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_search_monitors["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "delete_search_monitor" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "DELETE /searches/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.delete_search_monitor["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# GET /searches/{id}/summaries - List summaries for a monitor
resource "aws_apigatewayv2_integration" "list_search_summaries" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_search_summaries["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_search_summaries" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /searches/{id}/summaries"
  target             = "integrations/${aws_apigatewayv2_integration.list_search_summaries["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# GET /searches/{id}/summaries/{timestamp} - Get a specific summary
resource "aws_apigatewayv2_integration" "get_search_summary" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_search_summaries["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_search_summary" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /searches/{id}/summaries/{timestamp}"
  target             = "integrations/${aws_apigatewayv2_integration.get_search_summary["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# =============================================================================
# Lambda Permissions for API Gateway - Persistent Search
# =============================================================================

resource "aws_lambda_permission" "api_search_monitors" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_search_monitors["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_search_monitor_detail" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_search_monitor_detail["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_search_summaries" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_search_summaries["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}
