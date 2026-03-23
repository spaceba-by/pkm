@testable import PKMReader
import XCTest

final class ChatMessageTests: XCTestCase {
    // MARK: - MessageRole

    func test_messageRole_user_rawValue() {
        XCTAssertEqual(MessageRole.user.rawValue, "user")
    }

    func test_messageRole_assistant_rawValue() {
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
    }

    func test_messageRole_decodesFromJSON() throws {
        let json = Data("\"user\"".utf8)
        let role = try JSONDecoder().decode(MessageRole.self, from: json)
        XCTAssertEqual(role, .user)
    }

    // MARK: - MessageStatus

    func test_messageStatus_pending_rawValue() {
        XCTAssertEqual(MessageStatus.pending.rawValue, "pending")
    }

    func test_messageStatus_complete_rawValue() {
        XCTAssertEqual(MessageStatus.complete.rawValue, "complete")
    }

    func test_messageStatus_error_rawValue() {
        XCTAssertEqual(MessageStatus.error.rawValue, "error")
    }

    func test_messageStatus_decodesFromJSON() throws {
        let json = Data("\"complete\"".utf8)
        let status = try JSONDecoder().decode(MessageStatus.self, from: json)
        XCTAssertEqual(status, .complete)
    }

    // MARK: - ChatMessage

    func test_chatMessage_identifiable() {
        let message = ChatMessage(
            id: "msg-1",
            role: .user,
            content: "Hello",
            timestamp: "2026-03-22T12:00:00Z",
            status: .complete
        )
        XCTAssertEqual(message.id, "msg-1")
    }

    func test_chatMessage_codable_roundTrip() throws {
        let message = ChatMessage(
            id: "msg-1",
            role: .assistant,
            content: "Hi there",
            timestamp: "2026-03-22T12:00:00Z",
            status: .pending
        )
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.id, message.id)
        XCTAssertEqual(decoded.role, .assistant)
        XCTAssertEqual(decoded.content, "Hi there")
        XCTAssertEqual(decoded.status, .pending)
    }

    func test_chatMessage_hashable() {
        let msg1 = ChatMessage(id: "1", role: .user, content: "a", timestamp: "t", status: .complete)
        let msg2 = ChatMessage(id: "1", role: .user, content: "a", timestamp: "t", status: .complete)
        XCTAssertEqual(msg1, msg2)
    }

    // MARK: - ChatConversation

    func test_chatConversation_identifiable() {
        let convo = ChatConversation(
            id: "conv-1",
            title: "Test",
            created: "2026-03-22",
            modified: "2026-03-22",
            messageCount: 5,
            status: "active"
        )
        XCTAssertEqual(convo.id, "conv-1")
        XCTAssertEqual(convo.messageCount, 5)
    }

    func test_chatConversation_codable_roundTrip() throws {
        let convo = ChatConversation(
            id: "conv-1",
            title: "Test Chat",
            created: "2026-03-22",
            modified: "2026-03-22",
            messageCount: 3,
            status: "active"
        )
        let data = try JSONEncoder().encode(convo)
        let decoded = try JSONDecoder().decode(ChatConversation.self, from: data)
        XCTAssertEqual(decoded.id, convo.id)
        XCTAssertEqual(decoded.title, "Test Chat")
        XCTAssertEqual(decoded.messageCount, 3)
    }

    // MARK: - ChatSendRequest

    func test_chatSendRequest_encodesWithConversationId() throws {
        let request = ChatSendRequest(message: "Hello", conversationId: "conv-1")
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["message"] as? String, "Hello")
        XCTAssertEqual(json?["conversationId"] as? String, "conv-1")
    }

    func test_chatSendRequest_encodesWithNilConversationId() throws {
        let request = ChatSendRequest(message: "Hello", conversationId: nil)
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["message"] as? String, "Hello")
        XCTAssertNil(json?["conversationId"])
    }

    // MARK: - Response Types

    func test_chatConversationsResponse_decodable() throws {
        let jsonString = """
        {"conversations": [{"id": "c1", "title": "T", \
        "created": "d", "modified": "d", "messageCount": 1, \
        "status": "active"}]}
        """
        let json = Data(jsonString.utf8)
        let response = try JSONDecoder().decode(ChatConversationsResponse.self, from: json)
        XCTAssertEqual(response.conversations.count, 1)
        XCTAssertEqual(response.conversations[0].id, "c1")
    }

    func test_chatMessagesResponse_decodable() throws {
        let jsonString = """
        {"conversationId": "c1", "messages": [{"id": "m1", \
        "role": "user", "content": "hi", "timestamp": "t", \
        "status": "complete"}]}
        """
        let json = Data(jsonString.utf8)
        let response = try JSONDecoder().decode(ChatMessagesResponse.self, from: json)
        XCTAssertEqual(response.conversationId, "c1")
        XCTAssertEqual(response.messages.count, 1)
    }
}
