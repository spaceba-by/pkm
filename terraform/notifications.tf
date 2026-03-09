# =============================================================================
# Push Notifications Infrastructure
# SNS Platform Application, Lambda functions, DynamoDB Stream, API routes
# =============================================================================

locals {
  notifications_api_functions = var.enable_mobile_api ? [
    "api-device-tokens",
    "api-notifications"
  ] : []
}

# CloudWatch log groups for notification Lambda functions
resource "aws_cloudwatch_log_group" "notifications_api_logs" {
  for_each = toset(local.notifications_api_functions)

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}"
  })
}

resource "aws_cloudwatch_log_group" "notification_dispatch_logs" {
  for_each = local.mobile_api

  name              = "/aws/lambda/${var.project_name}-notification-dispatch"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-notification-dispatch"
  })
}

# =============================================================================
# SNS Platform Application for APNs
# =============================================================================

resource "aws_sns_platform_application" "apns" {
  for_each = local.mobile_api

  name                = "${var.project_name}-ios-push"
  platform            = var.apns_use_sandbox ? "APNS_SANDBOX" : "APNS"
  platform_credential = var.apns_signing_key
  platform_principal  = var.apns_signing_key_id

  apple_platform_team_id   = var.apns_team_id
  apple_platform_bundle_id = var.apns_bundle_id
}

# =============================================================================
# DynamoDB Stream for notification dispatch
# =============================================================================

# Note: DynamoDB Streams must be enabled on the table.
# This is configured via the stream_enabled and stream_view_type attributes
# on the aws_dynamodb_table resource in dynamodb.tf

# =============================================================================
# API Device Tokens Lambda (POST /devices, DELETE /devices/{device-id})
# =============================================================================

resource "aws_lambda_function" "api_device_tokens" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-device-tokens"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_device_tokens.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_device_tokens.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_device_tokens.zip" : null

  environment {
    variables = merge(local.api_lambda_environment, {
      SNS_PLATFORM_APPLICATION_ARN = try(aws_sns_platform_application.apns["enabled"].arn, "")
    })
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.notifications_api_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-device-tokens"
  })
}

# =============================================================================
# API Notifications Lambda (GET /notifications, PUT /notifications/{id}/read)
# =============================================================================

resource "aws_lambda_function" "api_notifications" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-api-notifications"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_notifications.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_notifications.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_notifications.zip" : null

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
    aws_cloudwatch_log_group.notifications_api_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-notifications"
  })
}

# =============================================================================
# Notification Dispatch Lambda (DynamoDB Stream trigger)
# =============================================================================

resource "aws_lambda_function" "notification_dispatch" {
  for_each = local.mobile_api

  function_name = "${var.project_name}-notification-dispatch"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 60
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/notification_dispatch.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/notification_dispatch.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/notification_dispatch.zip" : null

  environment {
    variables = merge(local.api_lambda_environment, {
      SNS_PLATFORM_APPLICATION_ARN = try(aws_sns_platform_application.apns["enabled"].arn, "")
    })
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.notification_dispatch_logs
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-notification-dispatch"
  })
}

# DynamoDB Stream event source mapping for notification dispatch
resource "aws_lambda_event_source_mapping" "notification_dispatch_stream" {
  for_each = local.mobile_api

  event_source_arn  = aws_dynamodb_table.metadata.stream_arn
  function_name     = aws_lambda_function.notification_dispatch["enabled"].arn
  starting_position = "LATEST"
  batch_size        = 10

  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT"]
        dynamodb = {
          NewImage = {
            SK = {
              S = [{ prefix = "notification#pending#" }]
            }
          }
        }
      })
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-notification-dispatch-stream"
  })
}

# =============================================================================
# API Gateway Routes - Device Tokens
# =============================================================================

# POST /devices - Register device token
resource "aws_apigatewayv2_integration" "register_device" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_device_tokens["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "register_device" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "POST /devices"
  target             = "integrations/${aws_apigatewayv2_integration.register_device["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# DELETE /devices/{device-id} - Unregister device
resource "aws_apigatewayv2_integration" "unregister_device" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_device_tokens["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "unregister_device" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "DELETE /devices/{device-id}"
  target             = "integrations/${aws_apigatewayv2_integration.unregister_device["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# =============================================================================
# API Gateway Routes - Notifications
# =============================================================================

# GET /notifications - List pending notifications
resource "aws_apigatewayv2_integration" "list_notifications" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_notifications["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_notifications" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /notifications"
  target             = "integrations/${aws_apigatewayv2_integration.list_notifications["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# PUT /notifications/{id}/read - Mark notification as read
resource "aws_apigatewayv2_integration" "mark_notification_read" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_notifications["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "mark_notification_read" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "PUT /notifications/{id}/read"
  target             = "integrations/${aws_apigatewayv2_integration.mark_notification_read["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# =============================================================================
# Lambda Permissions for API Gateway - Notifications
# =============================================================================

resource "aws_lambda_permission" "api_device_tokens" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_device_tokens["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_notifications" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_notifications["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}
