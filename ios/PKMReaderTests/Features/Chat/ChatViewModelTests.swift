@testable import PKMReader
import XCTest

@MainActor
final class ChatViewModelTests: XCTestCase {
    private var sut: ChatViewModel!
    private var mockAPIClient: MockAPIClient!

    override func setUp() async throws {
        mockAPIClient = MockAPIClient()
        sut = ChatViewModel(apiClient: mockAPIClient)
    }

    override func tearDown() async throws {
        sut = nil
        mockAPIClient = nil
    }

    // MARK: - Load Conversations

    func testLoadConversationsSuccess() async {
        let conversations = [
            ChatConversation(
                id: "conv-1", title: "Test Chat", created: "2026-03-14T00:00:00Z",
                modified: "2026-03-14T00:00:00Z", messageCount: 2, status: "active"
            ),
        ]
        mockAPIClient.listConversationsResult = .success(conversations)

        await sut.loadConversations()

        XCTAssertEqual(sut.conversations.count, 1)
        XCTAssertEqual(sut.conversations.first?.title, "Test Chat")
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(mockAPIClient.listConversationsCallCount, 1)
    }

    func testLoadConversationsFailure() async {
        mockAPIClient.listConversationsResult = .failure(APIError.invalidResponse)

        await sut.loadConversations()

        XCTAssertTrue(sut.conversations.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Open Conversation

    func testOpenConversationLoadsMessages() async {
        let messages = [
            ChatMessage(
                id: "msg-1", role: .user, content: "Hello",
                timestamp: "2026-03-14T00:00:00Z", status: .complete
            ),
        ]
        mockAPIClient.getConversationMessagesResult = .success(messages)

        await sut.openConversation("conv-1")

        XCTAssertEqual(sut.viewState, .conversation("conv-1"))
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages.first?.content, "Hello")
        XCTAssertEqual(mockAPIClient.getConversationMessagesCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastGetConversationMessagesId, "conv-1")
    }

    // MARK: - Send Message

    func testSendMessageSuccess() async {
        await sut.sendMessage()

        // Empty message should not send
        XCTAssertEqual(mockAPIClient.sendChatMessageCallCount, 0)
    }

    func testSendMessageWithContent() async {
        sut.inputText = "What meetings happened this week?"

        await sut.sendMessage()

        XCTAssertEqual(mockAPIClient.sendChatMessageCallCount, 1)
        XCTAssertEqual(mockAPIClient.lastSendChatMessage, "What meetings happened this week?")
        XCTAssertFalse(sut.isSending)
        XCTAssertTrue(sut.inputText.isEmpty)
    }

    func testSendMessageClearsInput() async {
        sut.inputText = "Test message"

        await sut.sendMessage()

        XCTAssertTrue(sut.inputText.isEmpty)
    }

    func testSendMessageSetsConversationId() async {
        sut.inputText = "Hello"

        await sut.sendMessage()

        XCTAssertNotNil(sut.currentConversationId)
        XCTAssertEqual(sut.currentConversationId, "test-conv-id")
    }

    func testSendMessageFailure() async {
        mockAPIClient.sendChatMessageResult = .failure(APIError.invalidResponse)
        sut.inputText = "Hello"

        await sut.sendMessage()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isSending)
    }

    // MARK: - New Conversation

    func testStartNewConversation() {
        sut.startNewConversation()

        XCTAssertNil(sut.currentConversationId)
        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertEqual(sut.viewState, .conversationList)
    }

    // MARK: - Pending Response

    func testHasPendingResponse() {
        XCTAssertFalse(sut.hasPendingResponse)
    }
}
