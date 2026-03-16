# =============================================================================
# Self-Improvement Dispatch Infrastructure
# ECS Fargate sandbox, Lambda functions, API Gateway routes
# =============================================================================

locals {
  dispatch_enabled = var.enable_dispatch ? { "enabled" = true } : {}
  dispatch_api     = var.enable_dispatch && var.enable_mobile_api ? { "enabled" = true } : {}

  dispatch_lambda_environment = merge(local.api_lambda_environment, {
    ECS_CLUSTER_NAME    = var.enable_dispatch ? aws_ecs_cluster.dispatch["enabled"].name : ""
    ECS_TASK_DEFINITION = var.enable_dispatch ? aws_ecs_task_definition.dispatch_sandbox["enabled"].arn : ""
    ECS_SUBNET_ID       = var.enable_dispatch ? aws_subnet.dispatch_public["enabled"].id : ""
    ECS_SECURITY_GROUP_ID = var.enable_dispatch ? aws_security_group.dispatch_sandbox["enabled"].id : ""
    DISPATCH_FUNCTION_NAME = var.enable_dispatch ? aws_lambda_function.dispatch_job["enabled"].function_name : ""
  })

  dispatch_api_lambda_functions = var.enable_dispatch && var.enable_mobile_api ? [
    "api-list-jobs",
    "api-get-job",
    "api-create-job",
    "api-claim-job",
    "api-complete-job",
    "api-agent-types"
  ] : []

  dispatch_processing_functions = var.enable_dispatch ? [
    "dispatch-job",
    "collect-results"
  ] : []
}

# =============================================================================
# VPC Resources (minimal, for Fargate networking)
# =============================================================================

resource "aws_vpc" "dispatch" {
  for_each = local.dispatch_enabled

  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-dispatch-vpc"
  })
}

resource "aws_subnet" "dispatch_public" {
  for_each = local.dispatch_enabled

  vpc_id                  = aws_vpc.dispatch["enabled"].id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-dispatch-public"
  })
}

resource "aws_internet_gateway" "dispatch" {
  for_each = local.dispatch_enabled

  vpc_id = aws_vpc.dispatch["enabled"].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-dispatch-igw"
  })
}

resource "aws_route_table" "dispatch_public" {
  for_each = local.dispatch_enabled

  vpc_id = aws_vpc.dispatch["enabled"].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dispatch["enabled"].id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-dispatch-public-rt"
  })
}

resource "aws_route_table_association" "dispatch_public" {
  for_each = local.dispatch_enabled

  subnet_id      = aws_subnet.dispatch_public["enabled"].id
  route_table_id = aws_route_table.dispatch_public["enabled"].id
}

resource "aws_security_group" "dispatch_sandbox" {
  for_each = local.dispatch_enabled

  name_prefix = "${var.project_name}-dispatch-sandbox-"
  vpc_id      = aws_vpc.dispatch["enabled"].id
  description = "Security group for dispatch sandbox tasks (egress only)"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-dispatch-sandbox-sg"
  })
}

# =============================================================================
# ECS Cluster and Task Definition
# =============================================================================

resource "aws_ecs_cluster" "dispatch" {
  for_each = local.dispatch_enabled

  name = "${var.project_name}-dispatch"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-dispatch-cluster"
  })
}

# ECS Task Execution Role (for pulling images and writing logs)
resource "aws_iam_role" "dispatch_ecs_execution" {
  for_each = local.dispatch_enabled

  name = "${var.project_name}-dispatch-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-dispatch-ecs-execution"
  })
}

resource "aws_iam_role_policy_attachment" "dispatch_ecs_execution" {
  for_each = local.dispatch_enabled

  role       = aws_iam_role.dispatch_ecs_execution["enabled"].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role (for S3 access from within the container)
resource "aws_iam_role" "dispatch_ecs_task" {
  for_each = local.dispatch_enabled

  name = "${var.project_name}-dispatch-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-dispatch-ecs-task"
  })
}

resource "aws_iam_role_policy" "dispatch_ecs_task_s3" {
  for_each = local.dispatch_enabled

  name = "s3-dispatch-access"
  role = aws_iam_role.dispatch_ecs_task["enabled"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.vault.arn,
          "${aws_s3_bucket.vault.arn}/_agent/dispatch/*"
        ]
      }
    ]
  })
}

resource "aws_ecs_task_definition" "dispatch_sandbox" {
  for_each = local.dispatch_enabled

  family                   = "${var.project_name}-dispatch-sandbox"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.dispatch_task_cpu
  memory                   = var.dispatch_task_memory
  execution_role_arn       = aws_iam_role.dispatch_ecs_execution["enabled"].arn
  task_role_arn            = aws_iam_role.dispatch_ecs_task["enabled"].arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "dispatch-sandbox"
    image     = var.dispatch_container_image
    essential = true

    environment = [
      { name = "S3_BUCKET", value = aws_s3_bucket.vault.id }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.dispatch_ecs["enabled"].name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "dispatch"
      }
    }
  }])

  tags = merge(var.tags, {
    Name = "${var.project_name}-dispatch-sandbox"
  })
}

# =============================================================================
# CloudWatch Log Groups
# =============================================================================

resource "aws_cloudwatch_log_group" "dispatch_ecs" {
  for_each = local.dispatch_enabled

  name              = "/aws/ecs/${var.project_name}-dispatch"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-dispatch-ecs-logs"
  })
}

resource "aws_cloudwatch_log_group" "dispatch_processing_logs" {
  for_each = toset(local.dispatch_processing_functions)

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}"
  })
}

resource "aws_cloudwatch_log_group" "dispatch_api_logs" {
  for_each = toset(local.dispatch_api_lambda_functions)

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = var.lambda_log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${each.key}"
  })
}

# =============================================================================
# Processing Lambda Functions
# =============================================================================

resource "aws_lambda_function" "dispatch_job" {
  for_each = local.dispatch_enabled

  function_name = "${var.project_name}-dispatch-job"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 60
  memory_size   = 512

  filename         = local.use_local_source ? "${path.module}/../lambda/target/dispatch_job.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/dispatch_job.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/dispatch_job.zip" : null

  environment {
    variables = local.dispatch_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [
    aws_cloudwatch_log_group.dispatch_processing_logs
  ]

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-dispatch-job"
  })
}

resource "aws_lambda_function" "collect_results" {
  for_each = local.dispatch_enabled

  function_name = "${var.project_name}-collect-results"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/collect_results.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/collect_results.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/collect_results.zip" : null

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
    aws_cloudwatch_log_group.dispatch_processing_logs
  ]

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-collect-results"
  })
}

# =============================================================================
# EventBridge: ECS Task State Change → collect_results
# =============================================================================

resource "aws_cloudwatch_event_rule" "dispatch_ecs_task_stopped" {
  for_each = local.dispatch_enabled

  name        = "${var.project_name}-dispatch-task-stopped"
  description = "Triggers result collection when dispatch ECS tasks stop"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      clusterArn    = [aws_ecs_cluster.dispatch["enabled"].arn]
      lastStatus    = ["STOPPED"]
      desiredStatus = ["STOPPED"]
    }
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-dispatch-task-stopped"
  })
}

resource "aws_cloudwatch_event_target" "dispatch_collect_results" {
  for_each = local.dispatch_enabled

  rule      = aws_cloudwatch_event_rule.dispatch_ecs_task_stopped["enabled"].name
  target_id = "collect-results"
  arn       = aws_lambda_function.collect_results["enabled"].arn
}

resource "aws_lambda_permission" "allow_eventbridge_collect_results" {
  for_each = local.dispatch_enabled

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collect_results["enabled"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.dispatch_ecs_task_stopped["enabled"].arn
}

# =============================================================================
# IAM: Lambda permissions for ECS
# =============================================================================

resource "aws_iam_role_policy" "lambda_ecs_dispatch" {
  for_each = local.dispatch_enabled

  name = "ecs-dispatch-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:StopTask"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "ecs:cluster" = aws_ecs_cluster.dispatch["enabled"].arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.dispatch_ecs_execution["enabled"].arn,
          aws_iam_role.dispatch_ecs_task["enabled"].arn
        ]
      }
    ]
  })
}

# =============================================================================
# API Lambda Functions
# =============================================================================

resource "aws_lambda_function" "api_list_jobs" {
  for_each = local.dispatch_api

  function_name = "${var.project_name}-api-list-jobs"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_list_jobs.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_list_jobs.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_list_jobs.zip" : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [aws_cloudwatch_log_group.dispatch_api_logs]

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = merge(var.tags, { Name = "${var.project_name}-api-list-jobs" })
}

resource "aws_lambda_function" "api_get_job" {
  for_each = local.dispatch_api

  function_name = "${var.project_name}-api-get-job"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_get_job.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_get_job.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_get_job.zip" : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [aws_cloudwatch_log_group.dispatch_api_logs]

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = merge(var.tags, { Name = "${var.project_name}-api-get-job" })
}

resource "aws_lambda_function" "api_create_job" {
  for_each = local.dispatch_api

  function_name = "${var.project_name}-api-create-job"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_create_job.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_create_job.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_create_job.zip" : null

  environment {
    variables = merge(local.api_lambda_environment, {
      DISPATCH_FUNCTION_NAME = aws_lambda_function.dispatch_job["enabled"].function_name
    })
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [aws_cloudwatch_log_group.dispatch_api_logs]

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = merge(var.tags, { Name = "${var.project_name}-api-create-job" })
}

resource "aws_lambda_function" "api_claim_job" {
  for_each = local.dispatch_api

  function_name = "${var.project_name}-api-claim-job"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_claim_job.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_claim_job.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_claim_job.zip" : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [aws_cloudwatch_log_group.dispatch_api_logs]

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = merge(var.tags, { Name = "${var.project_name}-api-claim-job" })
}

resource "aws_lambda_function" "api_complete_job" {
  for_each = local.dispatch_api

  function_name = "${var.project_name}-api-complete-job"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_complete_job.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_complete_job.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_complete_job.zip" : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [aws_cloudwatch_log_group.dispatch_api_logs]

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = merge(var.tags, { Name = "${var.project_name}-api-complete-job" })
}

resource "aws_lambda_function" "api_agent_types" {
  for_each = local.dispatch_api

  function_name = "${var.project_name}-api-agent-types"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler/handler"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256

  filename         = local.use_local_source ? "${path.module}/../lambda/target/api_agent_types.zip" : null
  source_code_hash = local.use_local_source ? filebase64sha256("${path.module}/../lambda/target/api_agent_types.zip") : null

  s3_bucket = local.use_s3_source ? var.lambda_artifacts_bucket_name : null
  s3_key    = local.use_s3_source ? "builds/${var.lambda_build_tag}/api_agent_types.zip" : null

  environment {
    variables = local.api_lambda_environment
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  depends_on = [aws_cloudwatch_log_group.dispatch_api_logs]

  lifecycle {
    precondition {
      condition     = var.lambda_source_type != "s3" || var.lambda_build_tag != ""
      error_message = "lambda_build_tag is required when lambda_source_type is 's3'."
    }
  }

  tags = merge(var.tags, { Name = "${var.project_name}-api-agent-types" })
}

# =============================================================================
# API Gateway Routes - Dispatch Jobs
# =============================================================================

# GET /dispatch/jobs - List jobs
resource "aws_apigatewayv2_integration" "list_jobs" {
  for_each = local.dispatch_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_list_jobs["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_jobs" {
  for_each = local.dispatch_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /dispatch/jobs"
  target             = "integrations/${aws_apigatewayv2_integration.list_jobs["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

resource "aws_lambda_permission" "api_list_jobs" {
  for_each = local.dispatch_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_list_jobs["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

# GET /dispatch/jobs/{jobId} - Get job details
resource "aws_apigatewayv2_integration" "get_job" {
  for_each = local.dispatch_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_get_job["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_job" {
  for_each = local.dispatch_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /dispatch/jobs/{jobId}"
  target             = "integrations/${aws_apigatewayv2_integration.get_job["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

resource "aws_lambda_permission" "api_get_job" {
  for_each = local.dispatch_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_get_job["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

# POST /dispatch/jobs - Create job
resource "aws_apigatewayv2_integration" "create_job" {
  for_each = local.dispatch_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_create_job["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create_job" {
  for_each = local.dispatch_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "POST /dispatch/jobs"
  target             = "integrations/${aws_apigatewayv2_integration.create_job["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

resource "aws_lambda_permission" "api_create_job" {
  for_each = local.dispatch_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_create_job["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

# POST /dispatch/jobs/claim - Claim a pending local job
resource "aws_apigatewayv2_integration" "claim_job" {
  for_each = local.dispatch_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_claim_job["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "claim_job" {
  for_each = local.dispatch_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "POST /dispatch/jobs/claim"
  target             = "integrations/${aws_apigatewayv2_integration.claim_job["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

resource "aws_lambda_permission" "api_claim_job" {
  for_each = local.dispatch_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_claim_job["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

# POST /dispatch/jobs/{jobId}/complete - Complete a job
resource "aws_apigatewayv2_integration" "complete_job" {
  for_each = local.dispatch_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_complete_job["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "complete_job" {
  for_each = local.dispatch_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "POST /dispatch/jobs/{jobId}/complete"
  target             = "integrations/${aws_apigatewayv2_integration.complete_job["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

resource "aws_lambda_permission" "api_complete_job" {
  for_each = local.dispatch_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_complete_job["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}

# GET /dispatch/agent-types - List agent types
# POST /dispatch/agent-types - Create agent type
# DELETE /dispatch/agent-types/{name} - Delete agent type
resource "aws_apigatewayv2_integration" "agent_types" {
  for_each = local.dispatch_api

  api_id                 = aws_apigatewayv2_api.pkm_api["enabled"].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_agent_types["enabled"].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_agent_types" {
  for_each = local.dispatch_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "GET /dispatch/agent-types"
  target             = "integrations/${aws_apigatewayv2_integration.agent_types["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

resource "aws_apigatewayv2_route" "create_agent_type" {
  for_each = local.dispatch_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "POST /dispatch/agent-types"
  target             = "integrations/${aws_apigatewayv2_integration.agent_types["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

resource "aws_apigatewayv2_route" "delete_agent_type" {
  for_each = local.dispatch_api

  api_id             = aws_apigatewayv2_api.pkm_api["enabled"].id
  route_key          = "DELETE /dispatch/agent-types/{name}"
  target             = "integrations/${aws_apigatewayv2_integration.agent_types["enabled"].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito["enabled"].id
}

resource "aws_lambda_permission" "api_agent_types" {
  for_each = local.dispatch_api

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_agent_types["enabled"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pkm_api["enabled"].execution_arn}/*/*"
}
