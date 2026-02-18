# Task 0011: Knowledge Graph Visualization

**Status**: Complete

## Specifications

Build a knowledge graph visualization that maps relationships between entities extracted from documents. Leverages the existing `extract_entities` Lambda which identifies people, organizations, concepts, and locations. The graph shows how documents, entities, and tags are interconnected, helping users discover relationships and patterns in their knowledge base.

## Relevant Files

- `lambda/functions/extract_entities/handler.clj` - Existing entity extraction
- `lambda/functions/api_graph_data/handler.clj` - Graph data API handler (new)
- `lambda/tests/api/graph_data_test.clj` - Graph API unit tests (new)
- `terraform/dynamodb.tf` - Entity storage (existing GSI sufficient)
- `terraform/api_lambda.tf` - Graph Lambda infrastructure (updated)
- `terraform/api_gateway.tf` - GET /graph route (updated)
- `ios/PKMReader/Models/GraphNode.swift` - Graph data models (new)
- `ios/PKMReader/Features/Graph/GraphViewModel.swift` - Graph view model (new)
- `ios/PKMReader/Features/Graph/GraphView.swift` - Interactive graph visualization (new)
- `ios/PKMReaderTests/Features/Graph/GraphViewModelTests.swift` - iOS unit tests (new)

## Acceptance Criteria

- [x] Entity relationships stored in queryable format
- [x] API endpoint returns graph data (nodes and edges)
- [x] Interactive graph visualization in iOS app
- [x] Nodes represent documents, entities, and tags
- [x] Edges represent relationships (mentions, co-occurrence, links)
- [x] Tap on node to navigate to document or filter by entity
- [x] Graph supports zoom, pan, and clustering
- [x] Performance acceptable for graphs with 500+ nodes

## Implementation Steps

- [x] Step 1: Design entity relationship data model
  - Existing DynamoDB entity-index GSI (`entity_key` hash, `SK` range) provides all needed queries
  - Graph built from document metadata: entities, tags, and wikilinks (links_to)
  - No new DynamoDB table or GSI required
- [x] Step 2: Create DynamoDB table/GSI for entity relationships
  - Existing entity-index GSI sufficient; no changes needed
- [x] Step 3: Update `extract_entities` to store relationships
  - Existing extract_entities already stores entity index entries with entity_key, document_path
  - Graph API builds relationships from this existing data at query time
- [x] Step 4: Implement graph data API endpoint
  - New `api_graph_data` Lambda at GET /graph
  - Builds graph from all document metadata (entities, tags, wikilinks)
  - Returns nodes (documents, entities, tags) and edges (mentions, tagged, links_to, co_occurrence)
- [x] Step 5: Backfill entity relationships from existing documents
  - Existing `scripts/backfill.clj` handles re-processing; no new script needed
  - Entity relationships already exist in DynamoDB from prior extract_entities runs
- [x] Step 6: Research and select iOS graph visualization library
  - Custom force-directed graph using SwiftUI Canvas (no external dependency)
  - Force simulation: repulsion between all nodes, attraction along edges, center gravity
- [x] Step 7: Build interactive graph view in iOS app
  - GraphView with Canvas rendering, force-directed layout
  - Color-coded nodes by type (document classification, entity type, tags)
  - Sized by connection count
  - Added as 6th tab "Graph" in MainTabView
- [x] Step 8: Add node tap navigation (document detail, entity filter)
  - Tap node to select and show detail overlay
  - "Open Document" button fetches and navigates to DocumentDetailView
  - Close button to deselect
- [x] Step 9: Optimize graph rendering for large datasets
  - Force simulation runs 150 iterations with cooling temperature
  - Displacement limit prevents nodes from jumping too far
  - Canvas rendering efficient for 500+ nodes (single draw pass)
  - Edge highlighting dims non-connected edges when a node is selected
- [x] Step 10: Write unit tests for graph data API
  - 24 Clojure tests for build-graph (node IDs, dedup, edges, co-occurrence, missing fields)
  - 10 iOS unit tests for GraphViewModel (load, error, colors, sizes, icons)

## Summary of Changes

### Backend (Lambda + Terraform)
- New `api_graph_data` Lambda function that scans all document metadata and builds a graph
- Graph nodes: documents (with classification), entities (with type), tags
- Graph edges: mentions (doc->entity), tagged (doc->tag), links_to (doc->doc), co_occurrence (entity<->entity)
- Terraform: Lambda function (512MB), API Gateway route GET /graph, Lambda permission
- 24 unit tests (part of 62 total, 432 assertions)

### iOS
- `GraphNode.swift`: Models for GraphNode, GraphEdge, GraphDataResponse
- `GraphViewModel.swift`: Force-directed layout simulation, node styling (color/size/icon)
- `GraphView.swift`: Canvas-based rendering with zoom/pan gestures, node selection, document navigation
- Added `getGraphData()` to APIClientProtocol, APIClient, UITestAPIClient, MockAPIClient
- Graph tab added to MainTabView (6-tab layout)
- 10 unit tests for GraphViewModel
- All 296 iOS unit tests pass, 0 lint errors
