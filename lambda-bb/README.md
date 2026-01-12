# PKM Agent System - Babashka Lambda Functions

This directory contains the Babashka (Clojure) implementations of the PKM Agent System Lambda functions, converted from Python.

## Project Structure

```
lambda-bb/
├── deps.edn              # Clojure dependencies
├── bb.edn                # Babashka configuration and tasks
├── shared/               # Shared utilities (used by all lambdas)
│   ├── aws/
│   │   ├── bedrock.clj   # AWS Bedrock client wrapper
│   │   ├── dynamodb.clj  # DynamoDB operations
│   │   ├── s3.clj        # S3 operations
│   │   └── lambda.clj    # Lambda invocation utilities
│   └── markdown/
│       └── utils.clj     # Markdown parsing & generation
├── functions/            # Individual lambda functions
│   ├── extract_metadata/
│   ├── update_classification_index/
│   ├── classify_document/
│   ├── extract_entities/
│   ├── generate_daily_summary/
│   └── generate_weekly_report/
└── tests/                # Unit tests

```

## Technology Stack

- **Runtime**: Babashka (Fast-loading Clojure scripting environment)
- **AWS SDK**: [Awwyeah](https://github.com/grzm/awyeah-api) - Idiomatic Clojure AWS client
- **Deployment**: Custom runtime (`provided.al2023`) with bootstrap binary
- **Build Tool**: bblf (Babashka Lambda Framework)

## Prerequisites

- [Babashka](https://github.com/babashka/babashka) >= 1.3.0
- [bblf](https://github.com/em-schmidt/bblf) - Babashka Lambda Framework
- AWS credentials configured

## Development

### REPL Development

```bash
# Start REPL with all dependencies loaded
bb repl
```

### Running Tests

```bash
# Run all tests
bb test
```

### Building Lambda Functions

Each lambda function can be built using bblf:

```bash
cd functions/extract_metadata
bb build.clj  # Creates bootstrap binary and deployment.zip
```

## Lambda Functions

| Function | Status | Description |
|----------|--------|-------------|
| extract-metadata | ✓ Converted | Parses markdown metadata, tags, and links |
| update-classification-index | 🔄 In Progress | Maintains classification index |
| classify-document | ⏳ Pending | AI-powered document classification |
| extract-entities | ⏳ Pending | Named entity extraction |
| generate-daily-summary | ⏳ Pending | Daily activity summaries |
| generate-weekly-report | ⏳ Pending | Weekly analysis reports |

## Advantages over Python

- **Performance**: ~100ms cold start vs 300-500ms for Python
- **Size**: Smaller deployment packages
- **Memory**: Typically 50% less memory usage
- **Development**: REPL-driven development for rapid iteration
- **Functional**: Immutable data structures, fewer state bugs

## Deployment

Lambdas are deployed via Terraform (see `../terraform/lambda.tf`). The Babashka versions use the `provided.al2023` custom runtime with a bootstrap binary.

## License

Same as parent project
