# Step Functions state machine for weekly report generation
resource "aws_sfn_state_machine" "generate_weekly_report" {
  name     = "${var.project_name}-generate-weekly-report"
  role_arn = aws_iam_role.stepfunctions_execution.arn

  definition = templatefile("${path.module}/../stepfunctions/weekly_report_workflow.json", {
    generate_weekly_report_lambda_arn = aws_lambda_function.generate_weekly_report.arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.stepfunctions_logs.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = var.enable_xray_tracing
  }

  tags = {
    Name = "${var.project_name}-generate-weekly-report"
  }

  depends_on = [
    aws_cloudwatch_log_resource_policy.stepfunctions_logs_policy,
    aws_iam_role_policy.stepfunctions_cloudwatch_logs
  ]
}

# CloudWatch log group for Step Functions
resource "aws_cloudwatch_log_group" "stepfunctions_logs" {
  name              = "/aws/vendedlogs/states/${var.project_name}-generate-weekly-report"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${var.project_name}-stepfunctions"
  }
}

# Resource policy for CloudWatch Logs to allow Step Functions
resource "aws_cloudwatch_log_resource_policy" "stepfunctions_logs_policy" {
  policy_name = "${var.project_name}-stepfunctions-logs"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = [
          "logs:CreateLogDelivery",
          "logs:PutLogEvents",
          "logs:PutLogEventsBatch",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:GetLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.stepfunctions_logs.arn}:*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:*"
          }
        }
      }
    ]
  })
}
