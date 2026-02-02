output "s3_bucket_name" {
  description = "Name of the S3 bucket for PKM vault"
  value       = aws_s3_bucket.vault.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for PKM vault"
  value       = aws_s3_bucket.vault.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for metadata"
  value       = aws_dynamodb_table.metadata.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for metadata"
  value       = aws_dynamodb_table.metadata.arn
}

output "lambda_function_names" {
  description = "Map of Lambda function names"
  value = {
    classify_document           = aws_lambda_function.classify_document.function_name
    extract_entities            = aws_lambda_function.extract_entities.function_name
    extract_metadata            = aws_lambda_function.extract_metadata.function_name
    generate_daily_summary      = aws_lambda_function.generate_daily_summary.function_name
    generate_weekly_report      = aws_lambda_function.generate_weekly_report.function_name
    update_classification_index = aws_lambda_function.update_classification_index.function_name
  }
}

output "stepfunctions_state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.generate_weekly_report.arn
}

output "cloudwatch_dashboard_url" {
  description = "URL to CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.pkm_agent.dashboard_name}"
}

output "rclone_remote_config" {
  description = "rclone configuration snippet for S3 remote"
  value       = <<-EOT
    [pkm-s3]
    type = s3
    provider = AWS
    env_auth = true
    region = ${var.aws_region}
    acl = private
  EOT
}

output "sync_command" {
  description = "Example rclone sync command"
  value       = "rclone bisync /path/to/local/vault pkm-s3:${aws_s3_bucket.vault.id} --conflict-resolve newer --conflict-loser rename"
}

output "setup_instructions" {
  description = "Next steps for setup"
  value       = <<-EOT
    Infrastructure deployed successfully!

    Next steps:
    1. Configure rclone using the config snippet above
    2. Run the sync setup script: cd ../scripts && ./setup-sync.sh
    3. Test the deployment: ./test-workflow.sh
    4. View CloudWatch dashboard: ${aws_cloudwatch_dashboard.pkm_agent.dashboard_name}

    S3 Bucket: ${aws_s3_bucket.vault.id}
    DynamoDB Table: ${aws_dynamodb_table.metadata.name}
  EOT
}

# CI/CD Outputs

output "lambda_artifacts_bucket_name" {
  description = "Name of the S3 bucket for Lambda build artifacts"
  value       = var.enable_lambda_artifacts_bucket ? aws_s3_bucket.lambda_artifacts["enabled"].id : null
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = var.enable_github_oidc ? aws_iam_role.github_actions["enabled"].arn : null
}

# =============================================================================
# Mobile API Outputs
# =============================================================================

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = var.enable_mobile_api ? aws_cognito_user_pool.pkm_users["enabled"].id : null
}

output "cognito_user_pool_endpoint" {
  description = "Cognito User Pool endpoint (issuer URL)"
  value       = var.enable_mobile_api ? "https://${aws_cognito_user_pool.pkm_users["enabled"].endpoint}" : null
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID (safe to embed in iOS app)"
  value       = var.enable_mobile_api ? aws_cognito_user_pool_client.ios_client["enabled"].id : null
}

output "cognito_identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = var.enable_mobile_api ? aws_cognito_identity_pool.pkm_identity["enabled"].id : null
}

output "api_gateway_url" {
  description = "API Gateway invocation URL"
  value       = var.enable_mobile_api ? aws_apigatewayv2_stage.api_default["enabled"].invoke_url : null
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = var.enable_mobile_api ? aws_apigatewayv2_api.pkm_api["enabled"].id : null
}

output "mobile_api_config" {
  description = "Configuration for iOS app (safe to embed)"
  value = var.enable_mobile_api ? {
    api_url          = aws_apigatewayv2_stage.api_default["enabled"].invoke_url
    cognito_region   = var.aws_region
    user_pool_id     = aws_cognito_user_pool.pkm_users["enabled"].id
    client_id        = aws_cognito_user_pool_client.ios_client["enabled"].id
    identity_pool_id = aws_cognito_identity_pool.pkm_identity["enabled"].id
  } : null
}
