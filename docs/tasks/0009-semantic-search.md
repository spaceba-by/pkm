# Task 0009: Semantic Search

**Status**: Complete

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

- [x] Vector index namespace with cosine similarity search and in-memory index management
- [x] Document chunking by heading structure produces meaningful chunks from Obsidian markdown
- [x] Embedding generation pipeline (Bedrock Titan or OpenAI) produces configurable-dimension vectors
- [x] Upsert pipeline indexes document chunks with insert-or-replace semantics
- [x] JSON index file stored in and loaded from S3
- [x] Vector similarity search returns relevant documents for natural language queries
- [x] `api_search` Lambda updated with `mode=keyword|semantic` parameter
- [x] Batch indexing script for initial corpus and incremental updates
- [x] Search performance acceptable for personal-scale corpus (<50k vectors)
- [x] Unit tests for chunking, vector index, and search functions (15 tests, 70 assertions)

## Implementation Steps

- [x] Step 1: Set up vector index — Created `lambda/shared/search/vector_index.clj` with pure Clojure cosine similarity search, in-memory index management, and upsert/remove/search operations. Adapted from DuckDB plan to use JSON-based index compatible with Babashka runtime.
- [x] Step 2: Implement document chunking — Created `lambda/shared/search/chunker.clj` that splits Obsidian documents by heading structure. Handles frontmatter stripping, no headings, deeply nested headings, and empty sections.
- [x] Step 3: Implement embedding generation — Created `lambda/shared/search/embeddings.clj` with support for Amazon Bedrock Titan Embeddings (default) and OpenAI text-embedding-3-small. Includes batching and provider-agnostic interface via `make-embedding-fn`.
- [x] Step 4: Create indexing pipeline — Created `lambda/shared/search/indexer.clj` that detects changed documents (diff against DynamoDB modified timestamps), chunks them, generates embeddings, and upserts into the vector index.
- [x] Step 5: Implement S3 index persistence — Index stored as JSON at `_agent/search/vector-index.json` in S3. Load on cold start, save after updates, handle first-run with empty index.
- [x] Step 6: Implement semantic search query — Created `lambda/shared/search/semantic.clj` with query embedding, cosine similarity search, and result grouping by document with best-score ranking.
- [x] Step 7: Update `api_search` Lambda — Added `mode=keyword|semantic` query parameter. Keyword search (default) uses existing DynamoDB scan. Semantic search loads cached index, embeds query via Bedrock, returns ranked results with scores. Also fixed keyword search to use `scan-all` for full results.
- [x] Step 8: Create batch indexing script — Built `scripts/index-embeddings.clj` with `--dry-run`, `--execute`, `--stats`, `--full`, `--prefix`, and `--limit` options. Created `lambda/functions/index_embeddings/handler.clj` Lambda for scheduled indexing.
- [x] Step 9: Write unit tests — 15 new test functions with 70 assertions across `vector_index_test.clj`, `chunker_test.clj`, and `semantic_test.clj`. Tests cover cosine similarity, index CRUD, chunking edge cases, and search ranking.
- [x] Step 10: Update iOS search view — Added `SearchMode` enum (keyword/semantic), segmented picker in toolbar, mode parameter in API protocol/client/mock. Updated `SearchViewModel` to retrigger search on mode change. Added 3 new unit tests for mode behavior.

## Future Considerations

- **Full-text search consolidation:** DuckDB's fts extension enables keyword and semantic search in a single query interface.
- **Note analytics:** Topic distribution, link graph queries, and writing pattern metrics from the same DuckDB instance.
- **Local embedding models:** nomic-embed-text via Ollama eliminates external API dependencies.
- **Iceberg migration:** If time-travel queries become valuable, storage layer could migrate from raw .duckdb to Iceberg tables.
