#!/bin/bash
# Bulk reclassify documents via direct Lambda invocation
# Usage:
#   ./scripts/bulk-reclassify.sh                          # Dry run (all documents)
#   ./scripts/bulk-reclassify.sh --execute                # Reclassify all documents
#   ./scripts/bulk-reclassify.sh --classification meeting  # Dry run (meetings only)
#   ./scripts/bulk-reclassify.sh --classification meeting --execute  # Reclassify meetings

set -euo pipefail

LAMBDA_NAME="pkm-agent-bulk-reclassify"
DRY_RUN=true
CLASSIFICATION=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --execute)
      DRY_RUN=false
      shift
      ;;
    --classification)
      CLASSIFICATION="$2"
      shift 2
      ;;
    --lambda-name)
      LAMBDA_NAME="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--execute] [--classification TYPE] [--lambda-name NAME]"
      echo ""
      echo "Options:"
      echo "  --execute           Actually reclassify (default is dry run)"
      echo "  --classification    Filter by current classification type"
      echo "  --lambda-name       Lambda function name (default: pkm-agent-bulk-reclassify)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Build payload using jq for safe JSON construction
INNER_BODY=$(jq -n \
  --argjson dry_run "$DRY_RUN" \
  --arg classification "$CLASSIFICATION" \
  '({dry_run: $dry_run} + (if $classification != "" then {classification: $classification} else {} end))')

PAYLOAD=$(jq -n --arg body "$INNER_BODY" '{body: $body}')

if [ "$DRY_RUN" = true ]; then
  echo "=== DRY RUN ==="
else
  echo "=== EXECUTING RECLASSIFICATION ==="
fi

echo "Lambda: $LAMBDA_NAME"
echo "Classification filter: ${CLASSIFICATION:-all}"
echo ""

aws lambda invoke \
  --function-name "$LAMBDA_NAME" \
  --payload "$PAYLOAD" \
  --cli-binary-format raw-in-base64-out \
  /dev/stdout 2>/dev/null | jq .
