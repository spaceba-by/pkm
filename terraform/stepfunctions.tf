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
}

# CloudWatch log group for Step Functions
resource "aws_cloudwatch_log_group" "stepfunctions_logs" {
  name              = "/aws/vendedlogs/states/${var.project_name}-generate-weekly-report"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${var.project_name}-stepfunctions"
  }
}
