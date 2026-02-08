# Task 0002: Processing Lambda Functions

**Status**: Complete

## Specifications

Implement the 6 core processing Lambda functions that power the PKM system. Originally written in Python, then migrated to Babashka/Clojure. These functions handle document classification, entity extraction, metadata parsing, daily summaries, weekly reports, and classification index maintenance.

## Relevant Files

- `lambda/functions/extract_metadata/handler.clj` - Parse frontmatter, tags, wiki-links
- `lambda/functions/classify_document/handler.clj` - AI classification via Bedrock (meeting/idea/reference/journal/project)
- `lambda/functions/extract_entities/handler.clj` - Named entity extraction (people, orgs, concepts, locations)
- `lambda/functions/generate_daily_summary/handler.clj` - Daily activity summaries (6 AM UTC)
- `lambda/functions/generate_weekly_report/handler.clj` - Weekly analysis reports (8 PM UTC Sunday)
- `lambda/functions/update_classification_index/handler.clj` - Maintain classification index in S3
- `lambda/shared/aws/bedrock.clj` - Bedrock client with retry logic
- `lambda/shared/aws/dynamodb.clj` - DynamoDB SDK wrapper
- `lambda/shared/aws/s3.clj` - S3 SDK wrapper
- `lambda/shared/markdown/parser.clj` - Markdown/frontmatter parsing
- `lambda/build.clj` - Build system for Lambda ZIPs with embedded Babashka
- `lambda/bb.edn` - Babashka project configuration
- `lambda/tests/` - Unit tests (27 tests, 158 assertions)

## Acceptance Criteria

- [x] `extract_metadata` parses YAML frontmatter, tags, and wiki-links from markdown files
- [x] `classify_document` sends document content to Bedrock and stores classification
- [x] `extract_entities` identifies people, organizations, concepts, and locations
- [x] `generate_daily_summary` aggregates daily activity into a summary document
- [x] `generate_weekly_report` produces weekly analysis with trends and insights
- [x] `update_classification_index` maintains a JSON index of classified documents
- [x] All functions use shared AWS SDK wrappers (S3, DynamoDB, Bedrock)
- [x] Build system produces deployable Lambda ZIP artifacts
- [x] Unit tests pass with adequate coverage

## Implementation Steps

- [x] Step 1: Implement shared AWS SDK wrappers (S3, DynamoDB, Bedrock)
- [x] Step 2: Implement markdown parser for frontmatter and wiki-links
- [x] Step 3: Build `extract_metadata` Lambda handler
- [x] Step 4: Build `classify_document` Lambda with Bedrock integration
- [x] Step 5: Build `extract_entities` Lambda with Bedrock integration
- [x] Step 6: Build `generate_daily_summary` Lambda with scheduled trigger
- [x] Step 7: Build `generate_weekly_report` Lambda with scheduled trigger
- [x] Step 8: Build `update_classification_index` Lambda
- [x] Step 9: Migrate from Python to Babashka/Clojure runtime
- [x] Step 10: Create build system with `bblf` Lambda framework
- [x] Step 11: Write unit tests for all handlers

## Summary of Changes

- Initially implemented 6 Lambda functions in Python
- Migrated all functions to Babashka/Clojure using `bblf` runtime framework
- Created shared AWS SDK wrappers (`bedrock.clj`, `dynamodb.clj`, `s3.clj`)
- Built markdown parser for YAML frontmatter and wiki-link extraction
- Implemented build system that packages Babashka binary + uberjar into Lambda ZIPs
- Added 27 unit tests with 158 assertions covering all handlers
- Removed Python Lambda code after migration was complete
- Key commits: `f4aa236` (Babashka migration), `a33eef7` (deploy with bblf runtime), `eed5214` (remove Python), `a6d5fde` (rename lambda-bb to lambda)
