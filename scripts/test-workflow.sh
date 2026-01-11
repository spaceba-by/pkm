#!/bin/bash

# PKM Agent System Test Script
# Tests the deployment by uploading a sample document and checking processing

set -e

echo "======================================"
echo "PKM Agent System Test"
echo "======================================"
echo ""

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    exit 1
fi

# Get bucket name from terraform outputs
if [ -f "../outputs.json" ]; then
    S3_BUCKET_NAME=$(jq -r '.s3_bucket_name.value' ../outputs.json)
    DYNAMODB_TABLE=$(jq -r '.dynamodb_table_name.value' ../outputs.json)
    echo "Using Terraform outputs:"
    echo "  Bucket: $S3_BUCKET_NAME"
    echo "  Table:  $DYNAMODB_TABLE"
else
    echo "Enter your S3 bucket name:"
    read -r S3_BUCKET_NAME

    echo "Enter your DynamoDB table name:"
    read -r DYNAMODB_TABLE
fi

echo ""
echo "======================================"
echo "Step 1: Create test document"
echo "======================================"

TEST_DOC=$(cat <<'EOF'
---
title: Test Meeting Notes
date: 2026-01-11
tags: [meeting, test]
---

# Project Kickoff Meeting

Had a productive meeting with the team about the new PKM agent system.

## Key Points
- Discussed architecture and design
- Decided on AWS services: Lambda, S3, DynamoDB, Bedrock
- Timeline: 2 weeks for MVP

## Action Items
- [ ] Set up AWS infrastructure
- [ ] Implement Lambda functions
- [ ] Test with sample documents

## Next Steps
Follow-up meeting next week to review progress.
EOF
)

TEST_FILE="/tmp/test-meeting-$(date +%s).md"
echo "$TEST_DOC" > "$TEST_FILE"
echo "✓ Created test document: $TEST_FILE"

echo ""
echo "======================================"
echo "Step 2: Upload to S3"
echo "======================================"

TEST_KEY="test/$(basename "$TEST_FILE")"
aws s3 cp "$TEST_FILE" "s3://$S3_BUCKET_NAME/$TEST_KEY"
echo "✓ Uploaded to s3://$S3_BUCKET_NAME/$TEST_KEY"

echo ""
echo "======================================"
echo "Step 3: Wait for processing"
echo "======================================"
echo "Waiting 30 seconds for Lambda functions to process..."
sleep 30

echo ""
echo "======================================"
echo "Step 4: Check DynamoDB"
echo "======================================"

echo "Querying DynamoDB for document metadata..."
METADATA=$(aws dynamodb get-item \
    --table-name "$DYNAMODB_TABLE" \
    --key "{\"PK\": {\"S\": \"doc#$TEST_KEY\"}, \"SK\": {\"S\": \"metadata\"}}" \
    --output json 2>/dev/null || echo "{}")

if [ "$(echo "$METADATA" | jq -r '.Item // empty')" != "" ]; then
    echo "✓ Document metadata found in DynamoDB"
    echo ""
    echo "Classification: $(echo "$METADATA" | jq -r '.Item.classification.S // "not found"')"
    echo "Title: $(echo "$METADATA" | jq -r '.Item.title.S // "not found"')"
    echo "Tags: $(echo "$METADATA" | jq -r '.Item.tags.L // [] | .[].S' | tr '\n' ', ')"
else
    echo "⚠ Document metadata not found in DynamoDB"
    echo "This may indicate:"
    echo "  1. Lambda functions haven't completed yet (wait longer)"
    echo "  2. EventBridge rules not triggering correctly"
    echo "  3. Lambda execution errors (check CloudWatch Logs)"
fi

echo ""
echo "======================================"
echo "Step 5: Check CloudWatch Logs"
echo "======================================"

echo "Recent Lambda invocations:"
aws logs tail "/aws/lambda/pkm-agent-classify-document" --since 5m --format short 2>/dev/null | tail -n 10 || echo "No logs found"

echo ""
echo "======================================"
echo "Step 6: Test daily summary (manual trigger)"
echo "======================================"

echo "Do you want to test the daily summary generation? (yes/no)"
read -r TEST_SUMMARY

if [ "$TEST_SUMMARY" = "yes" ]; then
    echo "Invoking daily summary Lambda..."

    RESULT=$(aws lambda invoke \
        --function-name pkm-agent-generate-daily-summary \
        --payload '{"date": "'$(date -u +%Y-%m-%d)'"}' \
        /tmp/summary-output.json 2>&1)

    if [ $? -eq 0 ]; then
        echo "✓ Daily summary Lambda invoked successfully"
        cat /tmp/summary-output.json | jq .
        echo ""
        echo "Check S3 for summary:"
        echo "  s3://$S3_BUCKET_NAME/_agent/summaries/$(date +%Y-%m-%d).md"
    else
        echo "⚠ Failed to invoke daily summary Lambda"
        echo "$RESULT"
    fi
fi

echo ""
echo "======================================"
echo "Step 7: Check agent outputs in S3"
echo "======================================"

echo "Listing agent-generated files..."
aws s3 ls "s3://$S3_BUCKET_NAME/_agent/" --recursive || echo "No agent files found yet"

echo ""
echo "======================================"
echo "Test Complete!"
echo "======================================"
echo ""
echo "Summary:"
echo "  ✓ Test document uploaded"
echo "  $([ "$(echo "$METADATA" | jq -r '.Item // empty')" != "" ] && echo "✓" || echo "⚠") Metadata stored in DynamoDB"
echo ""
echo "Next steps:"
echo "  1. Check CloudWatch Logs for detailed processing logs"
echo "  2. View CloudWatch Dashboard for metrics"
echo "  3. Upload more documents to test classification accuracy"
echo "  4. Wait for scheduled daily summary (runs at 6 AM UTC)"
echo ""
echo "Useful commands:"
echo "  # View logs"
echo "  aws logs tail /aws/lambda/pkm-agent-classify-document --follow"
echo ""
echo "  # List all documents in DynamoDB"
echo "  aws dynamodb scan --table-name $DYNAMODB_TABLE --filter-expression 'begins_with(PK, :pk)' --expression-attribute-values '{\":pk\":{\"S\":\"doc#\"}}'"
echo ""
echo "  # Download agent outputs"
echo "  aws s3 sync s3://$S3_BUCKET_NAME/_agent ./local-agent-outputs"
echo ""

# Cleanup
rm -f "$TEST_FILE" /tmp/summary-output.json
