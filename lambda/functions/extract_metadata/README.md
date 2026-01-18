# Extract Metadata Lambda (Babashka)

Extracts metadata from markdown documents without AI processing.

## What it does

1. Receives S3 events from EventBridge (when markdown files are uploaded/modified)
2. Downloads the markdown file from S3
3. Parses metadata using pure text processing:
   - YAML frontmatter
   - Hashtags (`#tag`)
   - Wikilinks (`[[link]]`)
   - Document title (from frontmatter or first H1)
4. Stores metadata in DynamoDB
5. Creates tag index entries for fast tag-based queries

## Key Features

- **No AI**: Pure parsing, very fast
- **Tag indexing**: Enables quick "find all documents with tag X" queries
- **Frontmatter extraction**: Preserves existing metadata
- **Wikilink tracking**: Builds document relationship graph

## Environment Variables

- `S3_BUCKET_NAME` - The S3 bucket containing markdown files
- `DYNAMODB_TABLE_NAME` - DynamoDB table for metadata storage

## Local Testing

```bash
# Set environment variables
export S3_BUCKET_NAME=your-bucket
export DYNAMODB_TABLE_NAME=your-table
export AWS_REGION=us-east-1

# Run handler
bb -m extract-metadata.handler -main
```

## Building

```bash
./build.clj
```

This creates `extract_metadata.zip` ready for Lambda deployment.

## Deployment

Deploy using Terraform (see `../../../terraform/lambda.tf`) or manually:

```bash
aws lambda update-function-code \
  --function-name pkm-extract-metadata-bb \
  --zip-file fileb://extract_metadata.zip
```

## Performance

- **Cold start**: ~100ms (vs 300-500ms for Python)
- **Memory**: 128-256 MB
- **Duration**: <1s for typical documents
