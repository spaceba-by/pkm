# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-lambda-execution"
  }
}

# Policy for S3 access
resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "s3-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.vault.arn,
          "${aws_s3_bucket.vault.arn}/*"
        ]
      }
    ]
  })
}

# Policy for DynamoDB access
resource "aws_iam_role_policy" "lambda_dynamodb_access" {
  name = "dynamodb-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.metadata.arn,
          "${aws_dynamodb_table.metadata.arn}/index/*"
        ]
      }
    ]
  })
}

# Policy for Bedrock access
resource "aws_iam_role_policy" "lambda_bedrock_access" {
  name = "bedrock-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-*",
          "arn:aws:bedrock:*:*:inference-profile/global.anthropic.claude-*"
        ]
      }
    ]
  })
}

# Policy for CloudWatch Logs
resource "aws_iam_role_policy" "lambda_cloudwatch_logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-*:*"
      }
    ]
  })
}

# Policy for X-Ray tracing (optional)
resource "aws_iam_role_policy" "lambda_xray" {
  count = var.enable_xray_tracing ? 1 : 0

  name = "xray-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy for SQS Dead Letter Queue access
resource "aws_iam_role_policy" "lambda_sqs_access" {
  name = "sqs-dlq-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.lambda_dlq.arn
      }
    ]
  })
}

# Policy for Lambda to invoke other Lambda functions (for update-classification-index)
resource "aws_iam_role_policy" "lambda_invoke" {
  name = "lambda-invoke"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-*"
      }
    ]
  })
}

# IAM role for Step Functions
resource "aws_iam_role" "stepfunctions_execution" {
  name = "${var.project_name}-stepfunctions-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-stepfunctions-execution"
  }
}

# Policy for Step Functions to invoke Lambda
resource "aws_iam_role_policy" "stepfunctions_lambda_invoke" {
  name = "lambda-invoke"
  role = aws_iam_role.stepfunctions_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-*"
      }
    ]
  })
}

# Policy for Step Functions CloudWatch Logs
resource "aws_iam_role_policy" "stepfunctions_cloudwatch_logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.stepfunctions_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DeleteLogDelivery",
          "logs:DescribeLogGroups",
          "logs:DescribeResourcePolicies",
          "logs:GetLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutLogEvents",
          "logs:PutResourcePolicy",
          "logs:UpdateLogDelivery"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy for Step Functions X-Ray tracing (optional)
resource "aws_iam_role_policy" "stepfunctions_xray" {
  count = var.enable_xray_tracing ? 1 : 0

  name = "xray-access"
  role = aws_iam_role.stepfunctions_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# GitHub Actions OIDC Provider (for keyless authentication)
resource "aws_iam_openid_connect_provider" "github" {
  count = var.github_repository != "" ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # AWS automatically validates GitHub's OIDC provider certificate chain,
  # so the thumbprint value is not used for verification. Using a placeholder.
  # See: https://github.com/aws-actions/configure-aws-credentials/issues/357
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]

  tags = merge(var.tags, {
    Name = "${var.project_name}-github-oidc"
  })
}

# IAM role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  count = var.github_repository != "" ? 1 : 0

  name = "${var.project_name}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-github-actions"
  })
}

# Policy for GitHub Actions to upload to artifacts bucket
resource "aws_iam_role_policy" "github_actions_s3" {
  count = var.github_repository != "" && var.lambda_artifacts_bucket_name != "" ? 1 : 0

  name = "s3-artifacts-upload"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.lambda_artifacts[0].arn,
          "${aws_s3_bucket.lambda_artifacts[0].arn}/*"
        ]
      }
    ]
  })
}
