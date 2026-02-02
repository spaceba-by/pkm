# =============================================================================
# Cognito User Pool - User Authentication for PKM Mobile API
# =============================================================================

resource "aws_cognito_user_pool" "pkm_users" {
  name = "${var.project_name}-users"

  # Username configuration - use email as username
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy - strong requirements
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  # Account recovery via email
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Email configuration (using Cognito default)
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # User attribute schema
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    string_attribute_constraints {
      min_length = 5
      max_length = 256
    }
  }

  # MFA configuration (optional but recommended)
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # Deletion protection for production
  deletion_protection = var.cognito_deletion_protection ? "ACTIVE" : "INACTIVE"

  tags = merge(var.tags, {
    Name = "${var.project_name}-users"
  })
}

# =============================================================================
# Cognito User Pool Client - iOS App
# =============================================================================

resource "aws_cognito_user_pool_client" "ios_client" {
  name         = "${var.project_name}-ios-client"
  user_pool_id = aws_cognito_user_pool.pkm_users.id

  # IMPORTANT: No client secret for mobile apps (SRP auth)
  generate_secret = false

  # Supported auth flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",        # Secure Remote Password - recommended for mobile
    "ALLOW_REFRESH_TOKEN_AUTH",   # Allow token refresh
    "ALLOW_USER_PASSWORD_AUTH"    # Allow direct password auth for testing
  ]

  # Token validity periods
  access_token_validity  = 1    # hours
  id_token_validity      = 1    # hours
  refresh_token_validity = 30   # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Prevent token revocation issues
  enable_token_revocation = true

  # Read-only attributes the app can access
  read_attributes = [
    "email",
    "email_verified"
  ]

  # No write attributes needed for read-only app
  write_attributes = []

  # Supported identity providers
  supported_identity_providers = ["COGNITO"]
}

# =============================================================================
# Cognito Identity Pool - AWS Credentials (for future direct AWS access)
# =============================================================================

resource "aws_cognito_identity_pool" "pkm_identity" {
  identity_pool_name               = "${var.project_name}-identity"
  allow_unauthenticated_identities = false
  allow_classic_flow               = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.ios_client.id
    provider_name           = aws_cognito_user_pool.pkm_users.endpoint
    server_side_token_check = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-identity"
  })
}

# =============================================================================
# IAM Roles for Cognito Identity Pool
# =============================================================================

resource "aws_iam_role" "cognito_authenticated" {
  name = "${var.project_name}-cognito-authenticated"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.pkm_identity.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-cognito-authenticated"
  })
}

# Minimal permissions for authenticated users (API access only)
resource "aws_iam_role_policy" "cognito_authenticated_policy" {
  name = "api-access"
  role = aws_iam_role.cognito_authenticated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = "${aws_apigatewayv2_api.pkm_api.execution_arn}/*"
      }
    ]
  })
}

# Attach roles to identity pool
resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.pkm_identity.id

  roles = {
    "authenticated" = aws_iam_role.cognito_authenticated.arn
  }
}
