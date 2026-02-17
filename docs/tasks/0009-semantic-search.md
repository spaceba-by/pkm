# Task 0009: Semantic Search

**Status**: Planned

## Specifications

Add semantic (vector similarity) search to the PKM system using DuckDB with the vss extension, replacing the original OpenSearch plan. The current `api_search` Lambda uses client-side filtering (fetching up to 500 documents and filtering in memory), which has O(n) performance. DuckDB provides vector search, full-text search, and analytical queries in a single embedded database file stored in S3, consistent with the system's serverless and file-based architecture.

### Design Constraints

- **No always-on infrastructure.** No persistent server or managed cluster (OpenSearch/Elasticsearch). Search workloads are low-frequency and can tolerate cold-start latency.
- **S3-native architecture.** The search index is a .duckdb file stored in S3 alongside source documents, avoiding additional managed datastores.
- **Complementary to DynamoDB.** DynamoDB remains the operational metadata store for key-value access patterns (sync state, document registry). DuckDB is a derived, read-optimized index over document content.
- **Supports incremental updates.** The indexing pipeline handles frequent appends and edits without requiring a full reindex.

### Technology Selection

| Component            | Selection                                                                            |
|----------------------|--------------------------------------------------------------------------------------|
| Vector store         | DuckDB with vss extension                                                            |
| Index format         | Persisted .duckdb file in S3 (preserves HNSW index across sessions)                  |
| Embedding model      | OpenAI text-embedding-3-small (1536d) or nomic-embed-text via Ollama for local use   |
| Application layer    | Clojure via next.jdbc + DuckDB JDBC driver (org.duckdb/duckdb_jdbc)                  |
| Operational metadata | DynamoDB (unchanged)                                                                 |

### Alternatives Evaluated

- **OpenSearch** — Rejected. Requires a persistent cluster; significant cost and operational overhead for personal-scale workload.
- **sqlite-vec** — Considered. Maximum simplicity and portability, but lacks native S3 integration and analytical query capabilities.
- **LanceDB** — Considered. Native S3 support with Lance columnar format, but introduces a new data format/toolchain with limited ecosystem overlap.
- **DuckDB with vss** — Selected. Native S3 and Parquet support, JDBC driver for Clojure integration, unified SQL interface for vector search + full-text search + analytics, single file as the entire search layer.

### Data Flow

The indexing pipeline operates as a batch process triggered by document changes or on a schedule:

1. Detect changed markdown files in S3 (diff against last index run, tracked via DynamoDB or manifest file)
2. Chunk documents by heading structure (natural fit for Obsidian-style notes with hierarchical headers)
3. Generate embeddings via embedding model API
4. Upsert vectors into DuckDB using `INSERT OR REPLACE`
5. Upload updated .duckdb file back to S3

### Schema

| Column     | Type       | Description                                 |
|------------|------------|---------------------------------------------|
| path       | VARCHAR    | S3 key of source markdown document          |
| chunk_id   | INTEGER    | Sequential chunk identifier within document |
| heading    | VARCHAR    | Section heading for context                 |
| content    | VARCHAR    | Raw text content of chunk                   |
| embedding  | FLOAT[1536]| Vector embedding (dimension matches model)  |
| updated_at | TIMESTAMP  | Last index time for change detection        |

Primary key: `(path, chunk_id)`. HNSW index on embedding column with cosine metric.

### Storage Format Rationale

DuckDB file chosen over raw Parquet (requires HNSW rebuild on every load) and Apache Iceberg (requires catalog infrastructure, overkill at personal scale). The .duckdb file preserves HNSW indexes across sessions, supports native SQL upserts, and keeps complexity minimal.

## Relevant Files

- `lambda/functions/api_search/handler.clj` — Current search implementation (to be updated)
- `lambda/shared/aws/duckdb.clj` — DuckDB client wrapper (to be created)
- `terraform/` — S3 configuration for .duckdb index file (if needed)
- `scripts/index-embeddings.clj` — Batch indexing script (to be created)

## Acceptance Criteria

- [ ] DuckDB wrapper namespace with next.jdbc integration and FLOAT[] array conversion
- [ ] Document chunking by heading structure produces meaningful chunks from Obsidian markdown
- [ ] Embedding generation pipeline (OpenAI or Ollama) produces 1536-dimension vectors
- [ ] Upsert pipeline indexes document chunks into DuckDB with `INSERT OR REPLACE`
- [ ] .duckdb index file stored in and loaded from S3
- [ ] Vector similarity search returns relevant documents for natural language queries
- [ ] `api_search` Lambda updated to query DuckDB for semantic search
- [ ] Batch indexing script for initial corpus and incremental updates
- [ ] Search performance acceptable for personal-scale corpus (<50k vectors)
- [ ] Unit tests for chunking, DuckDB wrapper, and search functions

## Implementation Steps

- [ ] Step 1: Set up DuckDB dependency — Add `org.duckdb/duckdb_jdbc` to the build system. Create `lambda/shared/aws/duckdb.clj` wrapper namespace with connection management, FLOAT[] array conversion helpers, and basic query functions via next.jdbc.
- [ ] Step 2: Implement document chunking — Create a markdown chunking module that splits Obsidian documents by heading structure. Each chunk includes the section heading, text content, and document path. Handle edge cases (no headings, deeply nested headings, frontmatter).
- [ ] Step 3: Implement embedding generation — Create an embedding client that calls OpenAI text-embedding-3-small (or nomic-embed-text via Ollama) to produce 1536-dimension vectors for text chunks. Include batching and rate limiting.
- [ ] Step 4: Create indexing pipeline — Build a batch process that detects changed documents (diff against DynamoDB or manifest), chunks them, generates embeddings, and upserts into DuckDB. Create the schema with HNSW index on the embedding column.
- [ ] Step 5: Implement S3 index persistence — Add functions to download the .duckdb file from S3 on cold start and upload back after index updates. Handle first-run (no existing index) and concurrent access.
- [ ] Step 6: Implement semantic search query — Add a search function that embeds the query text, runs cosine similarity search against the DuckDB index, and returns ranked results with path, heading, content snippet, and similarity score.
- [ ] Step 7: Update `api_search` Lambda — Integrate the DuckDB search into the existing API search endpoint. Support both keyword and semantic search modes.
- [ ] Step 8: Create batch indexing script — Build `scripts/index-embeddings.clj` for initial full-corpus indexing and scheduled incremental updates. Include dry-run mode, progress output, and configurable options.
- [ ] Step 9: Write unit tests — Test chunking logic, DuckDB wrapper functions, embedding pipeline, and search result ranking.
- [ ] Step 10: Update iOS search view — Surface semantic search results in the iOS app, distinguishing between keyword and semantic matches.

## Future Considerations

- **Full-text search consolidation:** DuckDB's fts extension enables keyword and semantic search in a single query interface.
- **Note analytics:** Topic distribution, link graph queries, and writing pattern metrics from the same DuckDB instance.
- **Local embedding models:** nomic-embed-text via Ollama eliminates external API dependencies.
- **Iceberg migration:** If time-travel queries become valuable, storage layer could migrate from raw .duckdb to Iceberg tables.
