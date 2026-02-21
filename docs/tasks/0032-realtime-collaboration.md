# Task 0032: Real-time Collaboration

**Status**: Planned

## Specifications

Add multi-user real-time collaboration features to the PKM system. Enable shared document editing, collaborative annotations, and live activity feeds. This is the largest-scope enhancement, requiring WebSocket infrastructure, conflict resolution, and presence management.

### Key Capabilities

- **Shared workspaces**: Users can share document collections with specific collaborators
- **Real-time editing**: Multiple users can view and edit the same document simultaneously
- **Conflict resolution**: Operational transformation (OT) or CRDT-based merge for concurrent edits
- **Presence indicators**: Show who is currently viewing or editing a document
- **Activity feed**: Real-time stream of changes across shared documents
- **Permissions**: Read-only, comment, and edit access levels per collaborator

### Architecture

- AWS API Gateway WebSocket API for real-time communication
- DynamoDB for session state, presence, and collaboration records
- Lambda handlers for WebSocket connect, disconnect, and message routing
- Conflict resolution strategy (OT or CRDT) for concurrent text edits

## Relevant Files

### New Lambda Functions
- `lambda/functions/ws_connect/handler.clj` — WebSocket connection handler
- `lambda/functions/ws_disconnect/handler.clj` — WebSocket disconnection handler
- `lambda/functions/ws_message/handler.clj` — WebSocket message router
- `lambda/functions/api_sharing/handler.clj` — Sharing and permissions API

### Terraform
- `terraform/websocket.tf` — WebSocket API Gateway, Lambda functions, DynamoDB tables
- `terraform/sharing.tf` — Sharing permissions and collaboration infrastructure

### iOS
- `ios/PKMReader/Core/Networking/WebSocketClient.swift` — WebSocket connection management
- `ios/PKMReader/Features/Collaboration/` — Sharing UI, presence indicators, activity feed

## Acceptance Criteria

- [ ] WebSocket API supports real-time bidirectional communication
- [ ] Documents can be shared with specific users at configurable access levels
- [ ] Concurrent edits resolve without data loss
- [ ] Presence indicators show active collaborators
- [ ] Activity feed streams real-time changes
- [ ] Sharing management UI in iOS app
- [ ] Unit tests for conflict resolution and message routing
- [ ] All existing tests continue to pass

## Implementation Steps

- [ ] Step 1: Design WebSocket message protocol and DynamoDB schema
- [ ] Step 2: Create WebSocket API Gateway with connect/disconnect/message routes
- [ ] Step 3: Implement connection and session management Lambdas
- [ ] Step 4: Create sharing and permissions API
- [ ] Step 5: Implement conflict resolution strategy (OT or CRDT)
- [ ] Step 6: Create iOS WebSocketClient
- [ ] Step 7: Build collaboration UI (sharing, presence, activity feed)
- [ ] Step 8: Add Terraform infrastructure
- [ ] Step 9: Write unit tests for conflict resolution and routing
