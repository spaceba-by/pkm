# Task 0011: Knowledge Graph Visualization

**Status**: Planned

## Specifications

Build a knowledge graph visualization that maps relationships between entities extracted from documents. Leverages the existing `extract_entities` Lambda which identifies people, organizations, concepts, and locations. The graph shows how documents, entities, and tags are interconnected, helping users discover relationships and patterns in their knowledge base.

## Relevant Files

- `lambda/functions/extract_entities/handler.clj` - Existing entity extraction
- `terraform/dynamodb.tf` - Entity storage (may need new table/GSI)
- `lambda/functions/` - Graph data API handlers (to be created)
- `ios/PKMReader/Views/` - Graph visualization view (to be created)

## Acceptance Criteria

- [ ] Entity relationships stored in queryable format
- [ ] API endpoint returns graph data (nodes and edges)
- [ ] Interactive graph visualization in iOS app
- [ ] Nodes represent documents, entities, and tags
- [ ] Edges represent relationships (mentions, co-occurrence, links)
- [ ] Tap on node to navigate to document or filter by entity
- [ ] Graph supports zoom, pan, and clustering
- [ ] Performance acceptable for graphs with 500+ nodes

## Implementation Steps

- [ ] Step 1: Design entity relationship data model
- [ ] Step 2: Create DynamoDB table/GSI for entity relationships
- [ ] Step 3: Update `extract_entities` to store relationships
- [ ] Step 4: Implement graph data API endpoint
- [ ] Step 5: Backfill entity relationships from existing documents
- [ ] Step 6: Research and select iOS graph visualization library
- [ ] Step 7: Build interactive graph view in iOS app
- [ ] Step 8: Add node tap navigation (document detail, entity filter)
- [ ] Step 9: Optimize graph rendering for large datasets
- [ ] Step 10: Write unit tests for graph data API
