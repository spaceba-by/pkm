#!/usr/bin/env bash
# Populate iOS app configuration files with real Cognito/API values from Terraform.
# Run from the repo root or the terraform/ directory.
#
# Usage:
#   ./scripts/configure-ios.sh
#   cd terraform && ../scripts/configure-ios.sh
#
# Prerequisites:
#   - terraform CLI installed
#   - AWS credentials configured
#   - terraform init already run in terraform/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$REPO_ROOT/terraform"
IOS_DIR="$REPO_ROOT/ios"

AMPLIFY_CONFIG="$IOS_DIR/PKMReader/Resources/amplifyconfiguration.json"
APP_CONFIG="$IOS_DIR/PKMReader/Core/Configuration/AppConfig.swift"

# Fetch values from Terraform
echo "Fetching Terraform outputs..."
cd "$TERRAFORM_DIR"

USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null) || {
    echo "ERROR: Could not read cognito_user_pool_id. Have you run 'terraform apply'?" >&2
    exit 1
}
CLIENT_ID=$(terraform output -raw cognito_client_id 2>/dev/null) || {
    echo "ERROR: Could not read cognito_client_id." >&2
    exit 1
}
IDENTITY_POOL_ID=$(terraform output -raw cognito_identity_pool_id 2>/dev/null) || {
    echo "ERROR: Could not read cognito_identity_pool_id." >&2
    exit 1
}
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null) || {
    echo "ERROR: Could not read api_gateway_url." >&2
    exit 1
}

# Extract region from pool ID (e.g. "us-east-1" from "us-east-1_AbCdEfGhI")
REGION="${USER_POOL_ID%%_*}"

echo "  User Pool ID:     $USER_POOL_ID"
echo "  Client ID:        $CLIENT_ID"
echo "  Identity Pool ID: $IDENTITY_POOL_ID"
echo "  API URL:          $API_URL"
echo "  Region:           $REGION"

# --- Update amplifyconfiguration.json ---
echo ""
echo "Writing $AMPLIFY_CONFIG ..."

cat > "$AMPLIFY_CONFIG" <<EOF
{
    "UserAgent": "aws-amplify-cli/0.1.0",
    "Version": "1.0",
    "auth": {
        "plugins": {
            "awsCognitoAuthPlugin": {
                "UserAgent": "aws-amplify-cli/0.1.0",
                "Version": "1.0",
                "IdentityManager": {
                    "Default": {}
                },
                "CognitoUserPool": {
                    "Default": {
                        "PoolId": "$USER_POOL_ID",
                        "AppClientId": "$CLIENT_ID",
                        "Region": "$REGION"
                    }
                },
                "CredentialsProvider": {
                    "CognitoIdentity": {
                        "Default": {
                            "PoolId": "$IDENTITY_POOL_ID",
                            "Region": "$REGION"
                        }
                    }
                },
                "Auth": {
                    "Default": {
                        "authenticationFlowType": "USER_SRP_AUTH"
                    }
                }
            }
        }
    }
}
EOF

# --- Update AppConfig.swift ---
echo "Writing $APP_CONFIG ..."

cat > "$APP_CONFIG" <<'SWIFT_EOF'
import Foundation

/// App configuration for the PKMReader app.
/// These are PUBLIC identifiers, not secrets.
/// Cognito client IDs are designed to be embedded in mobile apps.
/// The security comes from user authentication, not hidden identifiers.
///
/// Values populated by scripts/configure-ios.sh from Terraform outputs.
enum AppConfig {
    #if DEBUG
    // Development environment (same deployment for now)
    // swiftlint:disable:next force_unwrapping
SWIFT_EOF

# Append the dynamic parts (not in a heredoc so variables expand)
cat >> "$APP_CONFIG" <<SWIFT_DYNAMIC
    static let apiBaseURL = URL(string: "$API_URL")!
    static let cognitoUserPoolId = "$USER_POOL_ID"
    static let cognitoClientId = "$CLIENT_ID"
    static let cognitoIdentityPoolId = "$IDENTITY_POOL_ID"
SWIFT_DYNAMIC

cat >> "$APP_CONFIG" <<'SWIFT_EOF'
    #else
    // Production environment
    // swiftlint:disable:next force_unwrapping
SWIFT_EOF

cat >> "$APP_CONFIG" <<SWIFT_DYNAMIC
    static let apiBaseURL = URL(string: "$API_URL")!
    static let cognitoUserPoolId = "$USER_POOL_ID"
    static let cognitoClientId = "$CLIENT_ID"
    static let cognitoIdentityPoolId = "$IDENTITY_POOL_ID"
SWIFT_DYNAMIC

cat >> "$APP_CONFIG" <<'SWIFT_EOF'
    #endif

SWIFT_EOF

cat >> "$APP_CONFIG" <<SWIFT_DYNAMIC2
    static let cognitoRegion = "$REGION"
SWIFT_DYNAMIC2

cat >> "$APP_CONFIG" <<'SWIFT_EOF'

    /// App version from bundle
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Build number from bundle
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
SWIFT_EOF

echo ""
echo "Done! iOS configuration updated with real Cognito values."
echo ""
echo "Next steps:"
echo "  1. cd ios && xcodegen generate"
echo "  2. Open PKMReader.xcodeproj in Xcode"
echo "  3. Set your Development Team in Xcode's Signing & Capabilities"
echo "  4. Select your iPhone and hit Run"
