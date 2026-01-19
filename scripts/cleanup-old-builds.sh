#!/bin/bash

# Cleanup Old Builds Script
# Marks old undeployed Lambda build artifacts for deletion by S3 lifecycle policy.
# Objects tagged with lifecycle=expire will be deleted after 7 days.
#
# Usage:
#   ./cleanup-old-builds.sh --bucket BUCKET_NAME --deployed BUILD_TAG [--days N] [--dry-run]
#
# Example:
#   ./cleanup-old-builds.sh --bucket my-artifacts --deployed main-abc1234-20240115 --days 30

set -e

# Defaults
DAYS_OLD=30
DRY_RUN=false
BUCKET=""
DEPLOYED_TAG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --bucket)
            BUCKET="$2"
            shift 2
            ;;
        --deployed)
            DEPLOYED_TAG="$2"
            shift 2
            ;;
        --days)
            DAYS_OLD="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 --bucket BUCKET_NAME --deployed BUILD_TAG [--days N] [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --bucket     S3 bucket containing build artifacts (required)"
            echo "  --deployed   Currently deployed build tag to protect (required)"
            echo "  --days       Mark builds older than N days (default: 30)"
            echo "  --dry-run    Show what would be tagged without making changes"
            echo ""
            echo "Builds tagged with lifecycle=expire will be deleted after 7 days."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$BUCKET" ]; then
    echo "Error: --bucket is required"
    exit 1
fi

if [ -z "$DEPLOYED_TAG" ]; then
    echo "Error: --deployed is required"
    exit 1
fi

echo "======================================"
echo "Cleanup Old Build Artifacts"
echo "======================================"
echo ""
echo "Bucket: $BUCKET"
echo "Protected build: $DEPLOYED_TAG"
echo "Age threshold: $DAYS_OLD days"
echo "Dry run: $DRY_RUN"
echo ""

# Calculate cutoff date
if [[ "$OSTYPE" == "darwin"* ]]; then
    CUTOFF_DATE=$(date -v-${DAYS_OLD}d +%Y-%m-%dT%H:%M:%S)
else
    CUTOFF_DATE=$(date -d "${DAYS_OLD} days ago" +%Y-%m-%dT%H:%M:%S)
fi
echo "Cutoff date: $CUTOFF_DATE"
echo ""

# List all build directories
echo "Scanning builds..."
BUILD_DIRS=$(aws s3api list-objects-v2 \
    --bucket "$BUCKET" \
    --prefix "builds/" \
    --delimiter "/" \
    --query "CommonPrefixes[].Prefix" \
    --output text 2>/dev/null || echo "")

if [ -z "$BUILD_DIRS" ]; then
    echo "No builds found in bucket."
    exit 0
fi

TAGGED_COUNT=0
SKIPPED_COUNT=0
PROTECTED_COUNT=0

for BUILD_DIR in $BUILD_DIRS; do
    # Extract build tag from path (builds/BUILD_TAG/)
    BUILD_TAG=$(echo "$BUILD_DIR" | sed 's|builds/||' | sed 's|/$||')

    if [ -z "$BUILD_TAG" ]; then
        continue
    fi

    # Skip the currently deployed build
    if [ "$BUILD_TAG" == "$DEPLOYED_TAG" ]; then
        echo "[PROTECTED] $BUILD_TAG (currently deployed)"
        ((PROTECTED_COUNT++))
        continue
    fi

    # Get the manifest to check build date
    MANIFEST_KEY="builds/${BUILD_TAG}/manifest.json"
    MANIFEST=$(aws s3api head-object --bucket "$BUCKET" --key "$MANIFEST_KEY" 2>/dev/null || echo "")

    if [ -z "$MANIFEST" ]; then
        # No manifest, check any file in the directory for last modified
        SAMPLE_OBJ=$(aws s3api list-objects-v2 \
            --bucket "$BUCKET" \
            --prefix "builds/${BUILD_TAG}/" \
            --max-items 1 \
            --query "Contents[0].LastModified" \
            --output text 2>/dev/null || echo "")
        OBJ_DATE="$SAMPLE_OBJ"
    else
        OBJ_DATE=$(echo "$MANIFEST" | grep -o '"LastModified": "[^"]*"' | cut -d'"' -f4 2>/dev/null || \
            aws s3api head-object --bucket "$BUCKET" --key "$MANIFEST_KEY" --query "LastModified" --output text 2>/dev/null || echo "")
    fi

    if [ -z "$OBJ_DATE" ] || [ "$OBJ_DATE" == "None" ]; then
        echo "[SKIP] $BUILD_TAG (cannot determine age)"
        ((SKIPPED_COUNT++))
        continue
    fi

    # Compare dates (simple string comparison works for ISO format)
    OBJ_DATE_NORMALIZED=$(echo "$OBJ_DATE" | cut -d'.' -f1 | tr -d 'Z')

    if [[ "$OBJ_DATE_NORMALIZED" > "$CUTOFF_DATE" ]]; then
        echo "[KEEP] $BUILD_TAG (newer than $DAYS_OLD days)"
        ((SKIPPED_COUNT++))
        continue
    fi

    # Check if already tagged for expiration
    EXISTING_TAGS=$(aws s3api get-object-tagging \
        --bucket "$BUCKET" \
        --key "$MANIFEST_KEY" \
        --query "TagSet[?Key=='lifecycle'].Value" \
        --output text 2>/dev/null || echo "")

    if [ "$EXISTING_TAGS" == "expire" ]; then
        echo "[ALREADY TAGGED] $BUILD_TAG"
        ((SKIPPED_COUNT++))
        continue
    fi

    # Tag all objects in this build for expiration
    echo "[TAG FOR EXPIRATION] $BUILD_TAG (from $OBJ_DATE_NORMALIZED)"

    if [ "$DRY_RUN" == "false" ]; then
        # List all objects in this build directory
        OBJECTS=$(aws s3api list-objects-v2 \
            --bucket "$BUCKET" \
            --prefix "builds/${BUILD_TAG}/" \
            --query "Contents[].Key" \
            --output text 2>/dev/null || echo "")

        for OBJ_KEY in $OBJECTS; do
            aws s3api put-object-tagging \
                --bucket "$BUCKET" \
                --key "$OBJ_KEY" \
                --tagging '{"TagSet": [{"Key": "lifecycle", "Value": "expire"}]}'
        done
    fi

    ((TAGGED_COUNT++))
done

echo ""
echo "======================================"
echo "Summary"
echo "======================================"
echo "Protected (deployed): $PROTECTED_COUNT"
echo "Tagged for expiration: $TAGGED_COUNT"
echo "Skipped (recent or already tagged): $SKIPPED_COUNT"

if [ "$DRY_RUN" == "true" ] && [ "$TAGGED_COUNT" -gt 0 ]; then
    echo ""
    echo "This was a dry run. Run without --dry-run to apply changes."
fi

if [ "$TAGGED_COUNT" -gt 0 ] && [ "$DRY_RUN" == "false" ]; then
    echo ""
    echo "Tagged builds will be deleted by S3 lifecycle policy in 7 days."
fi
