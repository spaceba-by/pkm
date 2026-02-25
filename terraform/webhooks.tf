# =============================================================================
# Webhook Infrastructure (Task 0022)
# Lambda functions, API routes for webhook receiving and admin management
# =============================================================================

locals {
  webhook_api_functions = var.enable_mobile_api ? [
    "api-webhook-sources",
    "api-webhook-events"
  ] : []
}

# CloudWatch log groups for webhook admin API functions
resource "aws_cloudwatch_log_group" "webhook_api_logs" {
  for_each = toset(local.webhook_api_functions)

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}"
  })
}

# CloudWatch log group for the public webhook receiver
resource "aws_cloudwatch_log_group" "webhook_receive_logs" {
  for_each = local.mobile_api

  name              = "/aws/lambda/${var.project_name}-webhook-receive"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-webhook-receive"
  })
}

# =============================================================================
# webhook_receive Lambda (public endpoint, signature-verified)
# =============================================================================

resource "aws_lambda_function" "webhook_receive" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-webhook-receive"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/webhook_receive.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/webhook_receive.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/webhook_receive.zip" : null

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
    aws_cloudwatch_log_group.webhook_receive_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-webhook-receive"
  })
}

# =============================================================================
# api_webhook_sources Lambda (admin CRUD)
# =============================================================================

resource "aws_lambda_function" "api_webhook_sources" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-webhook-sources"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_webhook_sources.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_webhook_sources.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_webhook_sources.zip" : null

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
    aws_cloudwatch_log_group.webhook_api_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-webhook-sources"
  })
}

# =============================================================================
# api_webhook_events Lambda (admin read-only)
# =============================================================================

resource "aws_lambda_function" "api_webhook_events" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-webhook-events"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_webhook_events.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_webhook_events.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_webhook_events.zip" : null

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
    aws_cloudwatch_log_group.webhook_api_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-webhook-events"
  })
}

# =============================================================================
# API Gateway Routes - Webhook Receive (PUBLIC, no JWT)
# =============================================================================

resource "aws_apigatewayv2_integration" "webhook_receive" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.webhook_receive["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "webhook_receive" {
  for_each = local.mobile_api

  api_id    = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key = "POST /webhooks/{source-id}"
  target    = "integrations/${aws_apigatewayv2_integration.webhook_receive["enabled"].id}"
  # No authorization_type or authorizer_id — public route, signature-verified
}

# =============================================================================
# API Gateway Routes - Webhook Sources (admin CRUD)
# =============================================================================

resource "aws_apigatewayv2_integration" "webhook_sources" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_webhook_sources["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# POST /admin/webhook-sources
resource "aws_apigatewayv2_route" "webhook_sources_post" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "POST /admin/webhook-sources"
  target             = "integrations/${aws_apigatewayv2_integration.webhook_sources["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# GET /admin/webhook-sources
resource "aws_apigatewayv2_route" "webhook_sources_get" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /admin/webhook-sources"
  target             = "integrations/${aws_apigatewayv2_integration.webhook_sources["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# PUT /admin/webhook-sources/{id}
resource "aws_apigatewayv2_route" "webhook_sources_put" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "PUT /admin/webhook-sources/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.webhook_sources["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# DELETE /admin/webhook-sources/{id}
resource "aws_apigatewayv2_route" "webhook_sources_delete" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "DELETE /admin/webhook-sources/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.webhook_sources["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# =============================================================================
# API Gateway Routes - Webhook Events (admin read-only)
# =============================================================================

resource "aws_apigatewayv2_integration" "webhook_events" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_webhook_events["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# GET /admin/webhook-events
resource "aws_apigatewayv2_route" "webhook_events_get" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /admin/webhook-events"
  target             = "integrations/${aws_apigatewayv2_integration.webhook_events["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# =============================================================================
# Lambda Permissions for API Gateway
# =============================================================================

resource "aws_lambda_permission" "webhook_receive" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook_receive["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_webhook_sources" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_webhook_sources["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_webhook_events" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_webhook_events["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}
