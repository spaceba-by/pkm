# CloudWatch alarms for Lambda function errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = {
    "classify-document"           = aws_lambda_function.classify_document.function_name
    "extract-entities"            = aws_lambda_function.extract_entities.function_name
    "extract-metadata"            = aws_lambda_function.extract_metadata.function_name
    "generate-daily-summary"      = aws_lambda_function.generate_daily_summary.function_name
    "generate-weekly-report"      = aws_lambda_function.generate_weekly_report.function_name
    "update-classification-index" = aws_lambda_function.update_classification_index.function_name
  }

  alarm_name          = "${var.project_name}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when Lambda function ${each.key} has more than 5 errors in 5 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  tags = {
    Name = "${var.project_name}-${each.key}-errors"
  }
}

# CloudWatch alarms for Lambda function throttles
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = {
    "classify-document"           = aws_lambda_function.classify_document.function_name
    "extract-entities"            = aws_lambda_function.extract_entities.function_name
    "extract-metadata"            = aws_lambda_function.extract_metadata.function_name
    "generate-daily-summary"      = aws_lambda_function.generate_daily_summary.function_name
    "generate-weekly-report"      = aws_lambda_function.generate_weekly_report.function_name
    "update-classification-index" = aws_lambda_function.update_classification_index.function_name
  }

  alarm_name          = "${var.project_name}-${each.key}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when Lambda function ${each.key} is throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  tags = {
    Name = "${var.project_name}-${each.key}-throttles"
  }
}

# CloudWatch alarm for DLQ messages
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project_name}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alert when messages appear in the DLQ"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.lambda_dlq.name
  }

  tags = {
    Name = "${var.project_name}-dlq-messages"
  }
}

# CloudWatch alarm for Step Functions failed executions
resource "aws_cloudwatch_metric_alarm" "stepfunctions_failed" {
  alarm_name          = "${var.project_name}-stepfunctions-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when Step Functions execution fails"
  treat_missing_data  = "notBreaching"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.generate_weekly_report.arn
  }

  tags = {
    Name = "${var.project_name}-stepfunctions-failed"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "pkm_agent" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "classify-document" }],
            [".", ".", { stat = "Sum", label = "extract-entities" }],
            [".", ".", { stat = "Sum", label = "extract-metadata" }],
            [".", ".", { stat = "Sum", label = "generate-daily-summary" }],
            [".", ".", { stat = "Sum", label = "generate-weekly-report" }],
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Invocations"
          period  = 300
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", { stat = "Sum", label = "classify-document" }],
            [".", ".", { stat = "Sum", label = "extract-entities" }],
            [".", ".", { stat = "Sum", label = "extract-metadata" }],
            [".", ".", { stat = "Sum", label = "generate-daily-summary" }],
            [".", ".", { stat = "Sum", label = "generate-weekly-report" }],
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Errors"
          period  = 300
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", { stat = "Average", label = "classify-document" }],
            [".", ".", { stat = "Average", label = "extract-entities" }],
            [".", ".", { stat = "Average", label = "extract-metadata" }],
            [".", ".", { stat = "Average", label = "generate-daily-summary" }],
            [".", ".", { stat = "Average", label = "generate-weekly-report" }],
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Duration (ms)"
          period  = 300
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", { stat = "Sum" }],
            [".", "ConsumedWriteCapacityUnits", { stat = "Sum" }],
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "DynamoDB Capacity Units"
          period  = 300
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/States", "ExecutionsFailed", { stat = "Sum" }],
            [".", "ExecutionsSucceeded", { stat = "Sum" }],
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Step Functions Executions"
          period  = 300
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", { stat = "Average", label = "DLQ Messages" }],
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Dead Letter Queue"
          period  = 300
        }
      }
    ]
  })
}
