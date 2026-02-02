#!/bin/bash
# Create a test user in Cognito User Pool
# Usage: ./scripts/create-cognito-user.sh <email> <password>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <email> <password>"
    echo ""
    echo "Creates a confirmed user in the PKM Cognito User Pool."
    echo "The password must meet the following requirements:"
    echo "  - At least 12 characters"
    echo "  - At least one uppercase letter"
    echo "  - At least one lowercase letter"
    echo "  - At least one number"
    echo "  - At least one special character"
    exit 1
fi

EMAIL="$1"
PASSWORD="$2"

# Get User Pool ID from Terraform output
cd "$(dirname "$0")/../terraform"
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null || echo "")
cd - > /dev/null

if [ -z "$USER_POOL_ID" ] || [ "$USER_POOL_ID" = "null" ]; then
    echo "Error: Could not get Cognito User Pool ID from Terraform outputs"
    echo "Make sure the mobile API is deployed (enable_mobile_api = true)"
    exit 1
fi

echo "Creating user in User Pool: $USER_POOL_ID"
echo "Email: $EMAIL"

# Create user with temporary password (auto-confirmed)
aws cognito-idp admin-create-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$EMAIL" \
    --user-attributes Name=email,Value="$EMAIL" Name=email_verified,Value=true \
    --message-action SUPPRESS

echo "User created. Setting permanent password..."

# Set permanent password
aws cognito-idp admin-set-user-password \
    --user-pool-id "$USER_POOL_ID" \
    --username "$EMAIL" \
    --password "$PASSWORD" \
    --permanent

echo ""
echo "User created successfully!"
echo ""
echo "You can now test the API with:"
echo "  TEST_USER_EMAIL=$EMAIL TEST_USER_PASSWORD='$PASSWORD' ./scripts/test-api.sh"
