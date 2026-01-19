# EventBridge rule for S3 markdown file events
resource "aws_cloudwatch_event_rule" "s3_markdown_events" {
  name        = "${var.project_name}-s3-markdown-events"
  description = "Trigger processing when markdown files are uploaded to S3"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.vault.id]
      }
      object = {
        key = [{
          suffix = ".md"
        }]
      }
    }
  })

  tags = {
    Name = "${var.project_name}-s3-markdown-events"
  }
}

# Exclude _agent/ directory files from processing
resource "aws_cloudwatch_event_rule" "s3_markdown_events_exclude_agent" {
  name        = "${var.project_name}-s3-markdown-events-filter"
  description = "Filter to exclude _agent/ directory from processing"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.vault.id]
      }
      object = {
        key = [{
          suffix = ".md"
          }, {
          anything-but = {
            prefix = "_agent/"
          }
        }]
      }
    }
  })

  tags = {
    Name = "${var.project_name}-s3-markdown-events-filter"
  }
}

# Target: classify-document
resource "aws_cloudwatch_event_target" "classify_document" {
  rule      = aws_cloudwatch_event_rule.s3_markdown_events_exclude_agent.name
  target_id = "classify-document"
  arn       = aws_lambda_function.classify_document.arn
}

resource "aws_lambda_permission" "allow_eventbridge_classify" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.classify_document.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_markdown_events_exclude_agent.arn
}

# Target: extract-entities
resource "aws_cloudwatch_event_target" "extract_entities" {
  rule      = aws_cloudwatch_event_rule.s3_markdown_events_exclude_agent.name
  target_id = "extract-entities"
  arn       = aws_lambda_function.extract_entities.arn
}

resource "aws_lambda_permission" "allow_eventbridge_extract_entities" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.extract_entities.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_markdown_events_exclude_agent.arn
}

# Target: extract-metadata
resource "aws_cloudwatch_event_target" "extract_metadata" {
  rule      = aws_cloudwatch_event_rule.s3_markdown_events_exclude_agent.name
  target_id = "extract-metadata"
  arn       = aws_lambda_function.extract_metadata.arn
}

resource "aws_lambda_permission" "allow_eventbridge_extract_metadata" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.extract_metadata.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_markdown_events_exclude_agent.arn
}

# EventBridge rule for daily summary
resource "aws_cloudwatch_event_rule" "daily_summary_schedule" {
  name                = "${var.project_name}-daily-summary-schedule"
  description         = "Trigger daily summary generation"
  schedule_expression = var.daily_summary_schedule

  tags = {
    Name = "${var.project_name}-daily-summary-schedule"
  }
}

resource "aws_cloudwatch_event_target" "daily_summary" {
  rule      = aws_cloudwatch_event_rule.daily_summary_schedule.name
  target_id = "generate-daily-summary"
  arn       = aws_lambda_function.generate_daily_summary.arn
}

resource "aws_lambda_permission" "allow_eventbridge_daily_summary" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_daily_summary.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_summary_schedule.arn
}

# EventBridge rule for weekly report
resource "aws_cloudwatch_event_rule" "weekly_report_schedule" {
  name                = "${var.project_name}-weekly-report-schedule"
  description         = "Trigger weekly report generation"
  schedule_expression = var.weekly_report_schedule

  tags = {
    Name = "${var.project_name}-weekly-report-schedule"
  }
}

resource "aws_cloudwatch_event_target" "weekly_report" {
  rule      = aws_cloudwatch_event_rule.weekly_report_schedule.name
  target_id = "generate-weekly-report-workflow"
  arn       = aws_sfn_state_machine.generate_weekly_report.arn
  role_arn  = aws_iam_role.eventbridge_stepfunctions.arn
}

# IAM role for EventBridge to invoke Step Functions
resource "aws_iam_role" "eventbridge_stepfunctions" {
  name = "${var.project_name}-eventbridge-stepfunctions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-eventbridge-stepfunctions"
  }
}

resource "aws_iam_role_policy" "eventbridge_stepfunctions_invoke" {
  name = "stepfunctions-invoke"
  role = aws_iam_role.eventbridge_stepfunctions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = aws_sfn_state_machine.generate_weekly_report.arn
      }
    ]
  })
}
