# =============================================================================
# Insight Viewed-Status Infrastructure
# Lambda functions and API routes for tracking viewed status of insights
# =============================================================================

locals {
  insights_api_functions = var.enable_mobile_api ? [
    "api-mark-viewed",
    "api-insights-count"
  ] : []
}

# CloudWatch log groups for insight Lambda functions
resource "aws_cloudwatch_log_group" "insights_api_logs" {
  for_each = toset(local.insights_api_functions)

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}"
  })
}

# =============================================================================
# API Mark Viewed Lambda
# =============================================================================

resource "aws_lambda_function" "api_mark_viewed" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-mark-viewed"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  # Local source (default)
  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_mark_viewed.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_mark_viewed.zip") : null

  # S3 source (CI/CD)
  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_mark_viewed.zip" : null

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
    aws_cloudwatch_log_group.insights_api_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-mark-viewed"
  })
}

# =============================================================================
# API Insights Count Lambda
# =============================================================================

resource "aws_lambda_function" "api_insights_count" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-insights-count"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  # Local source (default)
  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_insights_count.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_insights_count.zip") : null

  # S3 source (CI/CD)
  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_insights_count.zip" : null

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
    aws_cloudwatch_log_group.insights_api_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-insights-count"
  })
}

# =============================================================================
# API Gateway Routes - Insight Viewed Status
# =============================================================================

# PUT /summaries/{date}/viewed
resource "aws_apigatewayv2_integration" "mark_summary_viewed" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_mark_viewed["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "mark_summary_viewed" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "PUT /summaries/{date}/viewed"
  target             = "integrations/${aws_apigatewayv2_integration.mark_summary_viewed["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# PUT /reports/{week}/viewed
resource "aws_apigatewayv2_route" "mark_report_viewed" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "PUT /reports/{week}/viewed"
  target             = "integrations/${aws_apigatewayv2_integration.mark_summary_viewed["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# PUT /searches/{id}/summaries/{timestamp}/viewed
resource "aws_apigatewayv2_route" "mark_search_summary_viewed" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "PUT /searches/{id}/summaries/{timestamp}/viewed"
  target             = "integrations/${aws_apigatewayv2_integration.mark_summary_viewed["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# PUT /insights/mark-all-viewed
resource "aws_apigatewayv2_route" "mark_all_viewed" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "PUT /insights/mark-all-viewed"
  target             = "integrations/${aws_apigatewayv2_integration.mark_summary_viewed["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# GET /insights/unviewed-count
resource "aws_apigatewayv2_integration" "insights_count" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_insights_count["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "insights_count" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /insights/unviewed-count"
  target             = "integrations/${aws_apigatewayv2_integration.insights_count["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# =============================================================================
# Lambda Permissions for API Gateway - Insights
# =============================================================================

resource "aws_lambda_permission" "api_mark_viewed" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_mark_viewed["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_insights_count" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_insights_count["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}
