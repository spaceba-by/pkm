import Foundation

/// View model for the Chat feature
@MainActor
@Observable
final class ChatViewModel: Sendable {
    enum ViewState: Equatable {
        case conversationList
        case conversation(String)
    }

    private(set) var conversations: [ChatConversation] = []
    private(set) var messages: [ChatMessage] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var errorMessage: String?
    var inputText = ""
    var viewState: ViewState = .conversationList
    private(set) var currentConversationId: String?

    private let apiClient: any APIClientProtocol
    private var pollingTask: Task<Void, Never>?

    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    func loadConversations() async {
        isLoading = true
        errorMessage = nil
        do {
            conversations = try await apiClient.listConversations()
        } catch {
            errorMessage = "Failed to load conversations"
        }
        isLoading = false
    }

    func openConversation(_ conversationId: String) async {
        viewState = .conversation(conversationId)
        currentConversationId = conversationId
        await loadMessages(conversationId: conversationId)
    }

    func loadMessages(conversationId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            messages = try await apiClient.getConversationMessages(conversationId: conversationId)
        } catch {
            errorMessage = "Failed to load messages"
        }
        isLoading = false
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        inputText = ""
        isSending = true
        errorMessage = nil

        do {
            let response = try await apiClient.sendChatMessage(
                message: text,
                conversationId: currentConversationId
            )

            // Update state with the new conversation
            if currentConversationId == nil {
                currentConversationId = response.conversationId
                viewState = .conversation(response.conversationId)
            }

            // Add the user message to local state
            messages.append(response.userMessage)

            // Add a pending assistant message
            let pendingMessage = ChatMessage(
                id: response.assistantMessageId,
                role: .assistant,
                content: "",
                timestamp: response.userMessage.timestamp,
                status: .pending
            )
            messages.append(pendingMessage)

            isSending = false

            // Start polling for the response
            startPolling(conversationId: response.conversationId,
                         assistantMessageId: response.assistantMessageId)
        } catch {
            isSending = false
            errorMessage = "Failed to send message"
        }
    }

    func startNewConversation() {
        stopPolling()
        currentConversationId = nil
        messages = []
        viewState = .conversationList
    }

    func backToConversations() async {
        stopPolling()
        currentConversationId = nil
        messages = []
        viewState = .conversationList
        await loadConversations()
    }

    private func startPolling(conversationId: String, assistantMessageId: String) {
        stopPolling()
        pollingTask = Task { [weak self] in
            // Poll every 2 seconds, up to 60 seconds
            for _ in 0..<30 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }

                do {
                    guard let self else { return }
                    let updatedMessages = try await self.apiClient.getConversationMessages(
                        conversationId: conversationId
                    )
                    self.messages = updatedMessages

                    // Check if the assistant message is complete
                    if let assistantMsg = updatedMessages.first(where: { $0.id == assistantMessageId }),
                       assistantMsg.status != .pending {
                        return
                    }
                } catch {
                    // Continue polling on error
                }
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Whether any assistant message is still pending
    var hasPendingResponse: Bool {
        messages.contains { $0.role == .assistant && $0.status == .pending }
    }
}
