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
      },
      {
        Effect = "Allow"
        Action = [
          "aws-marketplace:ViewSubscriptions",
          "aws-marketplace:Subscribe"
        ]
        Resource = [
          "*",
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
  for_each = local.xray_tracing

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
  for_each = local.xray_tracing

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
  for_each = local.github_oidc

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # AWS automatically validates GitHub's OIDC provider certificate chain,
  # so the thumbprint value is not used for verification, but we still set
  # GitHub's documented thumbprint for clarity and to satisfy security tooling.
  # See: https://github.com/aws-actions/configure-aws-credentials/issues/357
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.tags, {
    Name = "${var.project_name}-github-oidc"
  })
}

# IAM role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  for_each = local.github_oidc

  name = "${var.project_name}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github["enabled"].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_repository}:ref:refs/heads/main",
              "repo:${var.github_repository}:environment:production"
            ]
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
  for_each = local.github_artifacts_policy

  name = "s3-artifacts-upload"
  role = aws_iam_role.github_actions["enabled"].id

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
          aws_s3_bucket.lambda_artifacts["enabled"].arn,
          "${aws_s3_bucket.lambda_artifacts["enabled"].arn}/*"
        ]
      }
    ]
  })
}

# Policy for GitHub Actions to access Terraform state
# Only created when terraform_state_bucket_name is provided
resource "aws_iam_role_policy" "github_actions_terraform_state" {
  for_each = var.enable_github_oidc && var.terraform_state_bucket_name != "" ? { "enabled" = true } : {}

  name = "terraform-state-access"
  role = aws_iam_role.github_actions["enabled"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.terraform_state_bucket_name}",
          "arn:aws:s3:::${var.terraform_state_bucket_name}/*"
        ]
      },
      {
        Sid    = "DynamoDBStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-terraform-state-lock"
      }
    ]
  })
}

# Policy for GitHub Actions to manage Lambda functions
resource "aws_iam_role_policy" "github_actions_lambda" {
  for_each = local.github_oidc

  name = "lambda-management"
  role = aws_iam_role.github_actions["enabled"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaManagement"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:ListFunctions",
          "lambda:ListVersionsByFunction",
          "lambda:PublishVersion",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags",
          "lambda:PutFunctionEventInvokeConfig",
          "lambda:GetFunctionEventInvokeConfig",
          "lambda:DeleteFunctionEventInvokeConfig",
          "lambda:GetFunctionCodeSigningConfig"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-*"
      }
    ]
  })
}

# Policy for GitHub Actions to manage IAM roles and policies
resource "aws_iam_role_policy" "github_actions_iam" {
  for_each = local.github_oidc

  name = "iam-management"
  role = aws_iam_role.github_actions["enabled"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IAMRoleManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*"
        ]
      },
      {
        Sid    = "OIDCProviderManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:UntagOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviderTags"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
    ]
  })
}

# Policy for GitHub Actions to manage S3 buckets
resource "aws_iam_role_policy" "github_actions_s3_management" {
  for_each = local.github_oidc

  name = "s3-management"
  role = aws_iam_role.github_actions["enabled"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketManagement"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetBucketNotification",
          "s3:PutBucketNotification",
          "s3:GetBucketAcl",
          "s3:PutBucketAcl",
          "s3:GetBucketCors",
          "s3:PutBucketCors",
          "s3:DeleteBucketCors",
          "s3:GetBucketWebsite",
          "s3:GetBucketLogging",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketRequestPayment",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*",
          "arn:aws:s3:::${var.lambda_artifacts_bucket_name}",
          "arn:aws:s3:::${var.lambda_artifacts_bucket_name}/*",
          "arn:aws:s3:::${var.terraform_state_bucket_name}",
          "arn:aws:s3:::${var.terraform_state_bucket_name}/*"
        ]
      }
    ]
  })
}

# Policy for GitHub Actions to manage DynamoDB tables
resource "aws_iam_role_policy" "github_actions_dynamodb" {
  for_each = local.github_oidc

  name = "dynamodb-management"
  role = aws_iam_role.github_actions["enabled"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBManagement"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:DescribeTable",
          "dynamodb:UpdateTable",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:UpdateTimeToLive",
          "dynamodb:ListTagsOfResource",
          "dynamodb:TagResource",
          "dynamodb:UntagResource",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:UpdateContinuousBackups"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}",
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-terraform-state-lock"
        ]
      }
    ]
  })
}

# Policy for GitHub Actions to manage EventBridge
resource "aws_iam_role_policy" "github_actions_eventbridge" {
  for_each = local.github_oidc

  name = "eventbridge-management"
  role = aws_iam_role.github_actions["enabled"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EventBridgeRuleManagement"
        Effect = "Allow"
        Action = [
          "events:PutRule",
          "events:DeleteRule",
          "events:DescribeRule",
          "events:EnableRule",
          "events:DisableRule",
          "events:PutTargets",
          "events:RemoveTargets",
          "events:ListTargetsByRule",
          "events:TagResource",
          "events:UntagResource",
          "events:ListTagsForResource"
        ]
        Resource = "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/${var.project_name}-*"
      }
    ]
  })
}

# Policy for GitHub Actions to manage Step Functions
resource "aws_iam_role_policy" "github_actions_stepfunctions" {
  for_each = local.github_oidc

  name = "stepfunctions-management"
  role = aws_iam_role.github_actions["enabled"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StepFunctionsManagement"
        Effect = "Allow"
        Action = [
          "states:CreateStateMachine",
          "states:DeleteStateMachine",
          "states:DescribeStateMachine",
          "states:UpdateStateMachine",
          "states:ListStateMachineVersions",
          "states:TagResource",
          "states:UntagResource",
          "states:ListTagsForResource"
        ]
        Resource = "arn:aws:states:${var.aws_region}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.project_name}-*"
      }
    ]
  })
}

# Policy for GitHub Actions to manage CloudWatch
resource "aws_iam_role_policy" "github_actions_cloudwatch" {
  for_each = local.github_oidc

  name = "cloudwatch-management"
  role = aws_iam_role.github_actions["enabled"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsDescribe"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group::log-stream:"
      },
      {
        Sid    = "CloudWatchLogsManagement"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy",
          "logs:TagLogGroup",
          "logs:UntagLogGroup",
          "logs:ListTagsLogGroup",
          "logs:TagResource",
          "logs:UntagResource",
          "logs:ListTagsForResource"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vendedlogs/states/${var.project_name}-*"
        ]
      },
      {
        Sid    = "CloudWatchLogResourcePolicy"
        Effect = "Allow"
        Action = [
          "logs:PutResourcePolicy",
          "logs:DeleteResourcePolicy",
          "logs:DescribeResourcePolicies"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchDashboardManagement"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutDashboard",
          "cloudwatch:DeleteDashboards",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListDashboards"
        ]
        Resource = "arn:aws:cloudwatch::${data.aws_caller_identity.current.account_id}:dashboard/${var.project_name}-*"
      },
      {
        Sid    = "CloudWatchAlarmManagement"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:EnableAlarmActions",
          "cloudwatch:DisableAlarmActions",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource",
          "cloudwatch:ListTagsForResource"
        ]
        Resource = "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}-*"
      }
    ]
  })
}

# Policy for GitHub Actions to manage SQS (Dead Letter Queues)
resource "aws_iam_role_policy" "github_actions_sqs" {
  for_each = local.github_oidc

  name = "sqs-management"
  role = aws_iam_role.github_actions["enabled"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SQSManagement"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:SetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:TagQueue",
          "sqs:UntagQueue",
          "sqs:ListQueueTags"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-*"
      }
    ]
  })
}
