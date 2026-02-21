# Task 0023: Command Interface

**Status**: Planned

## Specifications

Build a unified command interface for interacting with the PKM system through multiple channels: a chat UI in the iOS app, @commands embedded in PKM notes, and API-based command submission. An AI reasoning agent (Bedrock Claude) processes commands by querying PKM data — documents, entities, classifications, summaries — and returns structured responses.

This consolidates two related concepts: an interactive chat interface for querying PKM knowledge, and a command direction system for sending instructions via notes or external triggers. The command interface handles both conversational queries ("What meetings mentioned Project X last week?") and directive commands ("@summarize all documents tagged #architecture").

### Key Capabilities

- **Chat UI**: iOS view for conversational interaction with the PKM knowledge base
- **@Command parsing**: Detect and process `@pkm` commands in documents during the extract_metadata pipeline
- **Conversation state**: Multi-turn conversations stored in DynamoDB with context windowing
- **PKM-aware reasoning**: Agent has access to document search, entity lookup, classification queries, and summary retrieval
- **Response delivery**: Chat responses returned via API; @command responses written to `_agent/responses/` in S3

### Architecture

```
Input Channels:
  iOS Chat UI → POST /chat
  @commands in notes → extract_metadata detects → async invocation
  Webhooks (Task 0022) → command routing

Command Processing:
  command_process Lambda
    ↓ builds context from PKM data (documents, entities, summaries)
    ↓ constructs prompt with relevant context
    ↓ invokes Bedrock Claude for reasoning
    ↓ stores response

Output:
  Chat → DynamoDB conversation record → API response
  @command → S3 _agent/responses/{document-path}.md
```

## Relevant Files

### New Lambda Functions
- `lambda/functions/command_process/handler.clj` — AI reasoning agent with PKM data access
- `lambda/functions/api_chat/handler.clj` — Chat API (POST message, GET conversation history)

### New Shared Libraries
- `lambda/shared/command/parser.clj` — @command detection and parsing
- `lambda/shared/command/context.clj` — PKM context builder (queries documents, entities, summaries)

### iOS (new)
- `ios/PKMReader/Features/Chat/ChatView.swift` — Chat conversation UI
- `ios/PKMReader/Features/Chat/ChatViewModel.swift` — Chat state management
- `ios/PKMReader/Models/ChatMessage.swift` — Message model

### Modified Files
- `lambda/functions/extract_metadata/handler.clj` — Add @command detection
- `ios/PKMReader/App/MainTabView.swift` — Add Chat tab (7-tab layout)

## Acceptance Criteria

- [ ] Chat API supports sending messages and retrieving conversation history
- [ ] AI agent queries PKM data to answer questions about documents, entities, and summaries
- [ ] Multi-turn conversation context maintained in DynamoDB
- [ ] @commands in PKM notes detected during document processing
- [ ] @command responses written to S3 `_agent/responses/` directory
- [ ] iOS chat view with message input, conversation history, and typing indicators
- [ ] Chat tab added to iOS app navigation
- [ ] Unit tests for command parsing, context building, and API handlers
- [ ] All existing tests continue to pass

## Implementation Steps

- [ ] Step 1: Design DynamoDB key schema for conversations and messages
- [ ] Step 2: Create @command parser for detecting commands in document content
- [ ] Step 3: Create PKM context builder (document search, entity lookup, summary retrieval)
- [ ] Step 4: Create command processing Lambda with Bedrock Claude reasoning
- [ ] Step 5: Create chat API Lambda (POST message, GET history)
- [ ] Step 6: Add @command detection to extract_metadata pipeline
- [ ] Step 7: Add Terraform infrastructure (Lambdas, API routes, IAM)
- [ ] Step 8: Create iOS ChatMessage model and ChatViewModel
- [ ] Step 9: Create ChatView with message list and input
- [ ] Step 10: Add Chat tab to MainTabView
- [ ] Step 11: Write unit tests for all new components
