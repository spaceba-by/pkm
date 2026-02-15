# =============================================================================
# API Gateway - HTTP API for PKM Mobile
# =============================================================================

resource "aws_apigatewayv2_api" "pkm_api" {
  for_each = local.mobile_api

  name          = "${var.project_name}-mobile-api"
  protocol_type = "HTTP"
  description   = "PKM Mobile API for iOS app"

  # Note: CORS configuration removed - not needed for native iOS apps.
  # CORS is a browser security mechanism and doesn't apply to mobile apps.

  tags = merge(var.tags, {
    Name = "${var.project_name}-mobile-api"
  })
}

# =============================================================================
# Cognito JWT Authorizer
# =============================================================================

resource "aws_apigatewayv2_authorizer" "cognito" {
  for_each = local.mobile_api

  api_id           = aws_apigatewayv2_api.pkm_api["enabled"].id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.ios_client["enabled"].id]
    issuer   = "https://${aws_cognito_user_pool.pkm_users["enabled"].endpoint}"
  }
}

# =============================================================================
# API Stage
# =============================================================================

resource "aws_apigatewayv2_stage" "api_default" {
  for_each = local.mobile_api

  api_id      = aws_apigatewayv2_api.pkm_api["enabled"].id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway["enabled"].arn
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
  for_each = local.mobile_api

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
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_documents["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_documents" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /documents"
  target             = "integrations/${aws_apigatewayv2_integration.list_documents["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# GET /documents/{key+} - Get single document (greedy path for nested keys)
resource "aws_apigatewayv2_integration" "get_document" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_get_document["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_document" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /documents/{key+}"
  target             = "integrations/${aws_apigatewayv2_integration.get_document["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# =============================================================================
# API Routes - Search
# =============================================================================

resource "aws_apigatewayv2_integration" "search" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_search["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "search" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /search"
  target             = "integrations/${aws_apigatewayv2_integration.search["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# =============================================================================
# API Routes - Tags
# =============================================================================

resource "aws_apigatewayv2_integration" "list_tags" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_tags["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_tags" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /tags"
  target             = "integrations/${aws_apigatewayv2_integration.list_tags["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

resource "aws_apigatewayv2_integration" "documents_by_tag" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_documents_by_tag["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "documents_by_tag" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /tags/{tag}/documents"
  target             = "integrations/${aws_apigatewayv2_integration.documents_by_tag["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# =============================================================================
# API Routes - Classifications
# =============================================================================

resource "aws_apigatewayv2_integration" "list_classifications" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_classifications["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_classifications" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /classifications"
  target             = "integrations/${aws_apigatewayv2_integration.list_classifications["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# =============================================================================
# API Routes - Summaries & Reports
# =============================================================================

resource "aws_apigatewayv2_integration" "list_summaries" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_summaries["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_summaries" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /summaries"
  target             = "integrations/${aws_apigatewayv2_integration.list_summaries["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

resource "aws_apigatewayv2_integration" "list_reports" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_reports["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_reports" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /reports"
  target             = "integrations/${aws_apigatewayv2_integration.list_reports["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# =============================================================================
# API Routes - Update Classification
# =============================================================================

resource "aws_apigatewayv2_integration" "update_classification" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_update_classification["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "update_classification" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "PUT /documents/classification/{key+}"
  target             = "integrations/${aws_apigatewayv2_integration.update_classification["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# =============================================================================
# API Routes - Bulk Reclassify
# =============================================================================

resource "aws_apigatewayv2_integration" "bulk_reclassify" {
  for_each = local.mobile_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_bulk_reclassify["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "bulk_reclassify" {
  for_each = local.mobile_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "POST /admin/reclassify"
  target             = "integrations/${aws_apigatewayv2_integration.bulk_reclassify["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

# =============================================================================
# Lambda Permissions for API Gateway
# =============================================================================

resource "aws_lambda_permission" "api_list_documents" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_documents["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_get_document" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_get_document["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_search" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_search["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list_tags" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_tags["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_documents_by_tag" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_documents_by_tag["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list_classifications" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_classifications["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list_summaries" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_summaries["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_list_reports" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_reports["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_update_classification" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_update_classification["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_bulk_reclassify" {
  for_each = local.mobile_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_bulk_reclassify["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}
