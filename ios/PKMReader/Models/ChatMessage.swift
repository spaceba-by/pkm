import Foundation

/// Role of a chat message sender
enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
}

/// Status of a chat message
enum MessageStatus: String, Codable, Sendable {
    case pending
    case complete
    case error
}

/// A single message in a chat conversation
struct ChatMessage: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let role: MessageRole
    let content: String
    let timestamp: String
    let status: MessageStatus
}

/// A chat conversation
struct ChatConversation: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let created: String
    let modified: String
    let messageCount: Int
    let status: String
}

// MARK: - API Request/Response Types

/// Request body for POST /chat
struct ChatSendRequest: Encodable, Sendable {
    let message: String
    let conversationId: String?
}

/// Response from POST /chat (202 Accepted)
struct ChatSendResponse: Codable, Sendable {
    let conversationId: String
    let userMessage: ChatMessage
    let assistantMessageId: String
}

/// Response from GET /chat
struct ChatConversationsResponse: Codable, Sendable {
    let conversations: [ChatConversation]
}

/// Response from GET /chat/{conversationId}
struct ChatMessagesResponse: Codable, Sendable {
    let conversationId: String
    let messages: [ChatMessage]
}
