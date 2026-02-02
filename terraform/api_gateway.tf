# =============================================================================
# API Gateway - HTTP API for PKM Mobile
# =============================================================================

resource "aws_apigatewayv2_api" "pkm_api" {
  name          = "${var.project_name}-mobile-api"
  protocol_type = "HTTP"
  description   = "PKM Mobile API for iOS app"

  # CORS configuration
  cors_configuration {
    allow_origins     = ["*"]
    allow_methods     = ["GET", "OPTIONS"]
    allow_headers     = ["Authorization", "Content-Type", "X-Request-ID"]
    expose_headers    = ["X-Request-ID"]
    max_age           = 300
    allow_credentials = false
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-mobile-api"
  })
}

# =============================================================================
# Cognito JWT Authorizer
# =============================================================================

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.pkm_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.ios_client.id]
    issuer   = "https://${aws_cognito_user_pool.pkm_users.endpoint}"
  }
}

# =============================================================================
# API Stage
# =============================================================================

resource "aws_apigatewayv2_stage" "api_default" {
  api_id      = aws_apigatewayv2_api.pkm_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
      userAgent        = "$context.identity.userAgent"
      cognitoSub       = "$context.authorizer.claims.sub"
    })
  }

  default_route_settings {
    throttling_burst_limit = var.api_throttle_burst_limit
    throttling_rate_limit  = var.api_throttle_rate_limit
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-default-stage"
  })
}

# =============================================================================
# CloudWatch Log Group for API Gateway
# =============================================================================

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-mobile-api"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-gateway-logs"
  })
}

# =============================================================================
# API Routes - Documents
# =============================================================================

# GET /documents - List all documents
resource "aws_apigatewayv2_integration" "list_documents" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_documents.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_documents" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /documents"
  target             = "integrations/${aws_apigatewayv2_integration.list_documents.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# GET /documents/{key+} - Get single document (greedy path for nested keys)
resource "aws_apigatewayv2_integration" "get_document" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_get_document.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_document" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /documents/{key+}"
  target             = "integrations/${aws_apigatewayv2_integration.get_document.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# =============================================================================
# API Routes - Search
# =============================================================================

resource "aws_apigatewayv2_integration" "search" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_search.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "search" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /search"
  target             = "integrations/${aws_apigatewayv2_integration.search.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# =============================================================================
# API Routes - Tags
# =============================================================================

resource "aws_apigatewayv2_integration" "list_tags" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_tags.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_tags" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /tags"
  target             = "integrations/${aws_apigatewayv2_integration.list_tags.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_integration" "documents_by_tag" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_documents_by_tag.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "documents_by_tag" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /tags/{tag}/documents"
  target             = "integrations/${aws_apigatewayv2_integration.documents_by_tag.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# =============================================================================
# API Routes - Classifications
# =============================================================================

resource "aws_apigatewayv2_integration" "list_classifications" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_classifications.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_classifications" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /classifications"
  target             = "integrations/${aws_apigatewayv2_integration.list_classifications.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# =============================================================================
# API Routes - Summaries & Reports
# =============================================================================

resource "aws_apigatewayv2_integration" "list_summaries" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_summaries.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_summaries" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /summaries"
  target             = "integrations/${aws_apigatewayv2_integration.list_summaries.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_integration" "list_reports" {
  api_id                 = aws_apigatewayv2_api.pkm_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_reports.arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_reports" {
  api_id             = aws_apigatewayv2_api.pkm_api.id
  route_key          = "GET /reports"
  target             = "integrations/${aws_apigatewayv2_integration.list_reports.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# =============================================================================
# Lambda Permissions for API Gateway
# =============================================================================

resource "aws_lambda_permission" "api_list_documents" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_documents.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_get_document" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_get_document.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_search" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_search.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list_tags" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_tags.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_documents_by_tag" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_documents_by_tag.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list_classifications" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_classifications.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list_summaries" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_summaries.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list_reports" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_reports.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*/*"
}
