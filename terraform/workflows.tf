# =============================================================================
# Custom Agent Workflows (Task 0026)
# Lambda functions, schedule rule, API Gateway routes
# =============================================================================

locals {
  workflows_enabled = var.enable_workflows ? { "enabled" = true } : {}
  workflows_api     = var.enable_workflows && var.enable_mobile_api ? { "enabled" = true } : {}

  workflow_dispatch_function_name = "${var.project_name}-workflow-dispatch"
  workflow_execute_function_name  = "${var.project_name}-workflow-execute"

  workflow_processing_functions = var.enable_workflows ? [
    "workflow-dispatch",
    "workflow-execute"
  ] : []

  workflow_api_functions = var.enable_workflows && var.enable_mobile_api ? [
    "api-workflows"
  ] : []

  workflow_api_routes = {
    list_workflows  = "GET /workflows"
    create_workflow = "POST /workflows"
    get_workflow    = "GET /workflows/{id}"
    update_workflow = "PUT /workflows/{id}"
    delete_workflow = "DELETE /workflows/{id}"
    run_workflow    = "POST /workflows/{id}/run"
    list_runs       = "GET /workflows/{id}/runs"
  }
}

# =============================================================================
# CloudWatch log groups
# =============================================================================

resource "aws_cloudwatch_log_group" "workflow_processing_logs" {
  for_each = toset(local.workflow_processing_functions)

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}"
  })
}

resource "aws_cloudwatch_log_group" "workflow_api_logs" {
  for_each = toset(local.workflow_api_functions)

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}"
  })
}

# =============================================================================
# Processing Lambda functions
# =============================================================================

# workflow-dispatch: match events against workflow definitions, queue runs
resource "aws_lambda_function" "workflow_dispatch" {
  for_each = local.workflows_enabled

  function_name = local.workflow_dispatch_function_name
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/workflow_dispatch.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/workflow_dispatch.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/workflow_dispatch.zip" : null

  environment {
    variables = merge(local.api_lambda_environment, {
      WORKFLOW_EXECUTE_FUNCTION_NAME = local.workflow_execute_function_name
    })
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [aws_cloudwatch_log_group.workflow_processing_logs]

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = merge(var.tags, {
    Name = local.workflow_dispatch_function_name
  })
}

# workflow-execute: render the prompt, invoke Bedrock, write output, record the run
resource "aws_lambda_function" "workflow_execute" {
  for_each = local.workflows_enabled

  function_name = local.workflow_execute_function_name
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 300
  memory_size   = 1024

  filename         = local.use_local_source ? "${path.module}/../lambda/target/workflow_execute.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/workflow_execute.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/workflow_execute.zip" : null

  environment {
    variables = merge(local.api_lambda_environment, {
      BEDROCK_HAIKU_MODEL_ID  = var.bedrock_haiku_model_id
      BEDROCK_SONNET_MODEL_ID = var.bedrock_sonnet_model_id
    })
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [aws_cloudwatch_log_group.workflow_processing_logs]

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = merge(var.tags, {
    Name = local.workflow_execute_function_name
  })
}

# =============================================================================
# Schedule polling: every 15 minutes, dispatch due schedule-triggered workflows
# =============================================================================

resource "aws_cloudwatch_event_rule" "workflow_schedule" {
  for_each = local.workflows_enabled

  name                = "${var.project_name}-workflow-schedule"
  description         = "Poll for due schedule-triggered custom agent workflows"
  schedule_expression = var.workflow_schedule_poll_rate

  tags = merge(var.tags, {
    Name = "${var.project_name}-workflow-schedule"
  })
}

resource "aws_cloudwatch_event_target" "workflow_schedule" {
  for_each = local.workflows_enabled

  rule      = aws_cloudwatch_event_rule.workflow_schedule["enabled"].name
  target_id = "workflow-dispatch"
  arn       = aws_lambda_function.workflow_dispatch["enabled"].arn
  input     = jsonencode({ trigger = "schedule" })
}

resource "aws_lambda_permission" "allow_eventbridge_workflow_schedule" {
  for_each = local.workflows_enabled

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.workflow_dispatch["enabled"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.workflow_schedule["enabled"].arn
}

# =============================================================================
# API Lambda function
# =============================================================================

resource "aws_lambda_function" "api_workflows" {
  for_each = local.workflows_api

  function_name = "${var.project_name}-api-workflows"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_workflows.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_workflows.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_workflows.zip" : null

  environment {
    variables = merge(local.api_lambda_environment, {
      WORKFLOW_EXECUTE_FUNCTION_NAME = local.workflow_execute_function_name
    })
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [aws_cloudwatch_log_group.workflow_api_logs]

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-workflows"
  })
}

# =============================================================================
# API Gateway routes: one integration, seven routes
# =============================================================================

resource "aws_apigatewayv2_integration" "workflows" {
  for_each = local.workflows_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_workflows["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "workflows" {
  for_each = var.enable_workflows && var.enable_mobile_api ? local.workflow_api_routes : {}

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = each.value
  target             = "integrations/${aws_apigatewayv2_integration.workflows["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

resource "aws_lambda_permission" "api_workflows" {
  for_each = local.workflows_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_workflows["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}
