# =============================================================================
# Centralized Secrets Manager Resources
# =============================================================================
#
# Naming convention: ${project_name}/<secret-name>
# All secrets follow the pattern: pkm-agent/<feature>-<key-type>
#
# Per-Lambda access: Pass secret ARN via environment variable (e.g., BRAVE_SEARCH_SECRET_ARN)
# IAM: Prefix-based wildcard policy in iam.tf grants access to all ${project_name}/* secrets
#
# Rotation: Managed externally (manual or CI/CD). Secrets Manager rotation is not
# configured — Lambda containers cache values in-memory for their lifetime.
# =============================================================================

# --- Brave Search API Key (Task 0013: Persistent Search) ---
resource "aws_secretsmanager_secret" "brave_search_api_key" {
  name        = "${var.project_name}/brave-search-api-key"
  description = "Brave Search API key for persistent search feature"

  tags = {
    Name = "${var.project_name}-brave-search-api-key"
  }
}

resource "aws_secretsmanager_secret_version" "brave_search_api_key" {
  count         = var.brave_search_api_key != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.brave_search_api_key.id
  secret_string = var.brave_search_api_key
}

# --- APNs Auth Key (Task 0021: Push Notifications) ---
# Placeholder — populate when push notifications are implemented
resource "aws_secretsmanager_secret" "apns_auth_key" {
  name        = "${var.project_name}/apns-auth-key"
  description = "APNs authentication key for iOS push notifications"

  tags = {
    Name = "${var.project_name}-apns-auth-key"
  }
}

# --- Webhook Signing Key (Task 0022: Webhook Receiving) ---
# Placeholder — populate when webhook receiving is implemented
resource "aws_secretsmanager_secret" "webhook_signing_key" {
  name        = "${var.project_name}/webhook-signing-key"
  description = "HMAC signing key for webhook signature verification"

  tags = {
    Name = "${var.project_name}-webhook-signing-key"
  }
}
