# Task 0023: Command Interface

**Status**: In Progress

## Specifications

Build a unified command interface for interacting with the PKM system through multiple channels: a chat UI in the iOS app, @sal commands embedded in PKM notes, and API-based command submission. An AI reasoning agent (Bedrock Claude Sonnet) processes commands by querying PKM data — documents, entities, classifications, summaries — and returns structured responses.

This consolidates two related concepts: an interactive chat interface for querying PKM knowledge, and a command direction system for sending instructions via notes or external triggers. The command interface handles both conversational queries ("What meetings mentioned Project X last week?") and directive commands ("@sal summarize all documents tagged #architecture").

### Key Capabilities

- **Chat UI**: iOS view for conversational interaction with the PKM knowledge base
- **@sal parsing**: Detect and process `@sal` commands in documents during the extract_metadata pipeline
- **Async chat pattern**: POST /chat returns 202 Accepted, command_process Lambda runs async, iOS polls for response
- **Conversation state**: Multi-turn conversations stored in DynamoDB with context windowing
- **PKM-aware reasoning**: Agent has access to document search, entity lookup, classification queries, and summary retrieval
- **Response delivery**: Chat responses returned via API; @sal command responses written to `_agent/responses/` in S3

### Architecture

```
Input Channels:
  iOS Chat UI → POST /chat (202 Accepted)
  @sal commands in notes → extract_metadata detects → async invocation

Command Processing:
  command_process Lambda (async, 120s timeout)
    ↓ loads conversation history from DynamoDB
    ↓ builds context from PKM data (documents, entities, summaries)
    ↓ constructs prompt with relevant context
    ↓ invokes Bedrock Claude Sonnet for reasoning
    ↓ stores response in DynamoDB (updates message status to "complete")

Output:
  Chat → DynamoDB message record (status: pending → complete) → iOS polls GET /chat/{id}
  @sal → S3 _agent/responses/{document-path-without-ext}/{timestamp}.md
```

### DynamoDB Schema

Conversation items: `PK=user#{sub}`, `SK=chat#{conversation-id}`
Message items: `PK=chat#{conversation-id}`, `SK=msg#{timestamp}#{message-id}`
@sal response tracking: `PK=<document-s3-key>`, `SK=COMMAND_RESPONSE#{timestamp}`

## Relevant Files

### New Lambda Functions
- `lambda/functions/command_process/handler.clj` — AI reasoning agent with PKM data access
- `lambda/functions/api_chat_send/handler.clj` — POST /chat (send message, return 202)
- `lambda/functions/api_chat_list/handler.clj` — GET /chat (list conversations)
- `lambda/functions/api_chat_messages/handler.clj` — GET /chat/{conversationId} (get messages)

### New Shared Libraries
- `lambda/shared/command/parser.clj` — @sal command detection and parsing
- `lambda/shared/command/context.clj` — PKM context builder (queries documents, entities, summaries)

### iOS (new)
- `ios/PKMReader/Features/Chat/ChatView.swift` — Chat conversation UI with message bubbles
- `ios/PKMReader/Features/Chat/ChatViewModel.swift` — Chat state management with polling
- `ios/PKMReader/Models/ChatMessage.swift` — Message and conversation models

### Modified Files
- `lambda/shared/aws/bedrock.clj` — Added `invoke-model-multi-turn` for conversation context
- `lambda/shared/api/response.clj` — Added `accepted` (202) response helper
- `lambda/functions/extract_metadata/handler.clj` — Added @sal command detection
- `terraform/lambda.tf` — Added command_process Lambda, updated extract_metadata env vars
- `terraform/api_lambda.tf` — Added 3 chat API Lambdas
- `terraform/api_gateway.tf` — Added 3 chat API routes + integrations + permissions
- `lambda/build.clj` — Added 4 new functions
- `lambda/bb.edn` — Added 4 new function paths
- `ios/PKMReader/App/MainTabView.swift` — Added Chat tab (5-tab layout)
- `ios/PKMReader/Core/Networking/APIClientProtocol.swift` — Added chat methods
- `ios/PKMReader/Core/Networking/APIClient.swift` — Added chat implementations
- `ios/PKMReader/Core/Testing/UITestAPIClient.swift` — Added chat fixtures
- `ios/PKMReaderTests/Mocks/MockAPIClient.swift` — Added chat mock methods

## Acceptance Criteria

- [x] Chat API supports sending messages and retrieving conversation history
- [x] AI agent queries PKM data to answer questions about documents, entities, and summaries
- [x] Multi-turn conversation context maintained in DynamoDB
- [x] @sal commands in PKM notes detected during document processing
- [x] @sal command responses written to S3 `_agent/responses/` directory
- [x] iOS chat view with message input, conversation history, and typing indicators
- [x] Chat tab added to iOS app navigation
- [x] Unit tests for command parsing, context building, and chat view model
- [ ] All existing tests continue to pass

## Implementation Steps

- [x] Step 1: Create @sal command parser (`lambda/shared/command/parser.clj`)
- [x] Step 2: Create PKM context builder (`lambda/shared/command/context.clj`)
- [x] Step 3: Add `invoke-model-multi-turn` to bedrock.clj and `accepted` to response.clj
- [x] Step 4: Create command processing Lambda with Bedrock Claude reasoning
- [x] Step 5: Create chat API Lambdas (send, list, messages)
- [x] Step 6: Add @sal command detection to extract_metadata pipeline
- [x] Step 7: Add Terraform infrastructure (Lambdas, API routes, permissions)
- [x] Step 8: Create iOS ChatMessage model, ChatViewModel, and ChatView
- [x] Step 9: Add Chat tab to MainTabView
- [x] Step 10: Write unit tests (parser, context, chat view model)
- [ ] Step 11: Verify all existing tests continue to pass
