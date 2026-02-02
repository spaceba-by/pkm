#!/bin/bash
# Integration tests for PKM Mobile API
# Usage: ./scripts/test-api.sh
#
# Required environment variables:
#   TEST_USER_EMAIL    - Email of test user in Cognito
#   TEST_USER_PASSWORD - Password of test user

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get API URL and auth from Terraform outputs
cd "$(dirname "$0")/../terraform"

echo -e "${YELLOW}Getting Terraform outputs...${NC}"
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null || echo "")
CLIENT_ID=$(terraform output -raw cognito_client_id 2>/dev/null || echo "")

cd - > /dev/null

# Validate outputs
if [ -z "$API_URL" ] || [ "$API_URL" = "null" ]; then
    echo -e "${RED}Error: Could not get API Gateway URL from Terraform outputs${NC}"
    echo "Make sure the mobile API is deployed (enable_mobile_api = true)"
    exit 1
fi

if [ -z "$USER_POOL_ID" ] || [ "$USER_POOL_ID" = "null" ]; then
    echo -e "${RED}Error: Could not get Cognito User Pool ID from Terraform outputs${NC}"
    exit 1
fi

if [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" = "null" ]; then
    echo -e "${RED}Error: Could not get Cognito Client ID from Terraform outputs${NC}"
    exit 1
fi

# Check required environment variables
if [ -z "$TEST_USER_EMAIL" ]; then
    echo -e "${RED}Error: TEST_USER_EMAIL environment variable is required${NC}"
    echo "Usage: TEST_USER_EMAIL=user@example.com TEST_USER_PASSWORD=password ./scripts/test-api.sh"
    exit 1
fi

if [ -z "$TEST_USER_PASSWORD" ]; then
    echo -e "${RED}Error: TEST_USER_PASSWORD environment variable is required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}=== PKM Mobile API Integration Tests ===${NC}"
echo "API URL: $API_URL"
echo "User Pool: $USER_POOL_ID"
echo "Client ID: $CLIENT_ID"
echo ""

# Authenticate with Cognito
echo -e "${YELLOW}Authenticating with Cognito...${NC}"
AUTH_RESULT=$(aws cognito-idp initiate-auth \
    --client-id "$CLIENT_ID" \
    --auth-flow USER_PASSWORD_AUTH \
    --auth-parameters USERNAME="$TEST_USER_EMAIL",PASSWORD="$TEST_USER_PASSWORD" 2>&1)

if echo "$AUTH_RESULT" | grep -q "AuthenticationResult"; then
    ACCESS_TOKEN=$(echo "$AUTH_RESULT" | jq -r '.AuthenticationResult.AccessToken')
    echo -e "${GREEN}Authentication successful${NC}"
else
    echo -e "${RED}Authentication failed${NC}"
    echo "$AUTH_RESULT"
    exit 1
fi

echo ""

# Test counters
PASSED=0
FAILED=0

# Test endpoint function
test_endpoint() {
    local name="$1"
    local path="$2"
    local expected_key="$3"  # Optional: key to check in response

    echo -n "Testing: $name ... "

    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        "$API_URL$path" 2>&1)

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | head -n -1)

    if [ "$HTTP_CODE" = "200" ]; then
        # If expected_key is provided, check it exists in response
        if [ -n "$expected_key" ]; then
            if echo "$BODY" | jq -e ".$expected_key" > /dev/null 2>&1; then
                echo -e "${GREEN}PASS${NC} (HTTP $HTTP_CODE)"
                ((PASSED++))
            else
                echo -e "${RED}FAIL${NC} (missing key: $expected_key)"
                echo "  Response: $(echo "$BODY" | head -c 200)"
                ((FAILED++))
            fi
        else
            echo -e "${GREEN}PASS${NC} (HTTP $HTTP_CODE)"
            ((PASSED++))
        fi
    else
        echo -e "${RED}FAIL${NC} (HTTP $HTTP_CODE)"
        echo "  Response: $BODY"
        ((FAILED++))
    fi
}

# Run tests
echo -e "${YELLOW}Running API tests...${NC}"
echo ""

test_endpoint "GET /documents" "/documents" "documents"
test_endpoint "GET /documents?classification=meeting" "/documents?classification=meeting&limit=5" "documents"
test_endpoint "GET /search?q=test" "/search?q=test" "results"
test_endpoint "GET /tags" "/tags" "tags"
test_endpoint "GET /classifications" "/classifications" "classifications"
test_endpoint "GET /summaries" "/summaries" "summaries"
test_endpoint "GET /reports" "/reports" "reports"

echo ""
echo -e "${YELLOW}=== Test Results ===${NC}"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
