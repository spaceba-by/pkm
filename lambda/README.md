# PKM Agent System - Babashka Lambda Functions

This directory contains the Babashka (Clojure) implementations of the PKM Agent System Lambda functions, converted from Python.

## Project Structure

```
lambda/
├── deps.edn              # Clojure dependencies
├── bb.edn                # Babashka configuration and tasks
├── shared/               # Shared utilities (used by all lambdas)
│   ├── api/
│   │   └── response.clj  # API response utilities
│   ├── aws/
│   │   ├── bedrock.clj          # AWS Bedrock client wrapper
│   │   ├── dynamodb.clj         # DynamoDB operations
│   │   ├── s3.clj               # S3 operations
│   │   ├── sns.clj              # SNS push notification operations
│   │   ├── lambda.clj           # Lambda invocation utilities
│   │   ├── secrets_manager.clj  # Secrets Manager with caching
│   │   └── brave_search.clj     # Brave Search API client
│   ├── markdown/
│   │   └── utils.clj            # Markdown parsing & generation
│   ├── notifications/
│   │   └── utils.clj            # Push notification dispatch utilities
│   └── search/
│       ├── chunker.clj          # Document chunking by heading
│       ├── embeddings.clj       # Vector embedding generation
│       ├── indexer.clj          # Incremental index builder
│       ├── semantic.clj         # Semantic search engine
│       └── vector_index.clj     # In-memory vector index
├── functions/            # Individual lambda functions
│   ├── extract_metadata/
│   ├── classify_document/
│   ├── extract_entities/
│   ├── update_classification_index/
│   ├── generate_daily_summary/
│   ├── generate_weekly_report/
│   ├── bulk_reclassify/
│   ├── delete_document/
│   ├── persistent_search_execute/
│   ├── persistent_search_summarize/
│   ├── index_embeddings/          # CLI utility (not deployed)
│   ├── api_list_documents/
│   ├── api_get_document/
│   ├── api_search/
│   ├── api_list_tags/
│   ├── api_documents_by_tag/
│   ├── api_list_classifications/
│   ├── api_list_summaries/
│   ├── api_list_reports/
│   ├── api_update_classification/
│   ├── api_bulk_reclassify/
│   ├── api_create_document/
│   ├── api_update_document/
│   ├── api_delete_document/
│   ├── api_graph_data/
│   ├── api_search_monitors/
│   ├── api_search_monitor_detail/
│   ├── api_search_summaries/
│   ├── notification_dispatch/
│   ├── api_device_tokens/
│   └── api_notifications/
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

Lambda functions are built using the top-level build script:

```bash
bb build.clj                      # Build all functions
bb build.clj extract_metadata     # Build a single function
```

Output ZIPs are placed in `target/`.

## Lambda Functions

### Processing (11)

| Function | Description |
|----------|-------------|
| extract-metadata | Parses markdown metadata, tags, and links |
| classify-document | AI-powered document classification |
| extract-entities | Named entity extraction |
| update-classification-index | Maintains classification index (scheduled every 6 hours) |
| generate-daily-summary | Daily activity summaries |
| generate-weekly-report | Weekly analysis reports |
| bulk-reclassify | Bulk reclassification with dry-run mode and filtering |
| delete-document | Cascade-delete DynamoDB records on S3 object deletion |
| persistent-search-execute | Execute search monitors via Brave Search API |
| persistent-search-summarize | AI-driven summarization of search results |
| notification-dispatch | Dispatch push notifications via SNS/APNs (DynamoDB Stream trigger) |

### Mobile API (19)

| Function | Description |
|----------|-------------|
| api-list-documents | List documents with optional classification filter |
| api-get-document | Get document with content |
| api-search | Search by title, path, tags (keyword/semantic) |
| api-list-tags | List all tags with counts |
| api-documents-by-tag | Get documents by specific tag |
| api-list-classifications | List classification types with counts |
| api-list-summaries | List daily AI summaries |
| api-list-reports | List weekly AI reports |
| api-update-classification | Classification feedback/correction (PUT) |
| api-bulk-reclassify | Trigger bulk reclassification (POST) |
| api-create-document | Create new document (admin only, POST) |
| api-update-document | Update existing document (admin only, PUT) |
| api-delete-document | Delete document (admin only, DELETE) |
| api-graph-data | Entity relationship graph data (GET) |
| api-search-monitors | Manage persistent search monitors (CRUD) |
| api-search-monitor-detail | Single search monitor operations |
| api-search-summaries | Search result summaries |
| api-device-tokens | Register/unregister device tokens for push notifications |
| api-notifications | List and acknowledge push notifications |

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
