import SwiftUI

/// Main chat view with conversation list and message views
struct ChatView: View {
    let apiClient: any APIClientProtocol
    @State private var viewModel: ChatViewModel

    init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
        _viewModel = State(initialValue: ChatViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.viewState {
                case .conversationList:
                    ConversationListView(viewModel: viewModel)
                case .conversation:
                    ChatConversationView(viewModel: viewModel)
                }
            }
        }
        .task {
            await viewModel.loadConversations()
        }
    }
}

// MARK: - Conversation List

private struct ConversationListView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.conversations.isEmpty {
                ProgressView("Loading conversations...")
            } else if viewModel.conversations.isEmpty {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "bubble.left.and.text.bubble.right",
                    description: Text("Start a new chat to query your knowledge base.")
                )
            } else {
                List(viewModel.conversations) { conversation in
                    Button {
                        Task {
                            await viewModel.openConversation(conversation.id)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(conversation.messageCount) messages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .accessibilityIdentifier("conversation-\(conversation.id)")
                }
            }
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.viewState = .conversation("")
                    viewModel.inputText = ""
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New Chat")
                .accessibilityIdentifier("NewChatButton")
            }
        }
    }
}

// MARK: - Conversation View

private struct ChatConversationView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }

                        if viewModel.hasPendingResponse {
                            TypingIndicator()
                                .id("typing-indicator")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) {
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            ChatInputBar(
                text: $viewModel.inputText,
                isSending: viewModel.isSending || viewModel.hasPendingResponse,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }
            )
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {
                    Task {
                        await viewModel.backToConversations()
                    }
                }
                .accessibilityIdentifier("BackToConversations")
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.role == .user ? Color.accentColor : Color(.systemGray5))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if message.status == .error {
                    Label("Error", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .accessibilityIdentifier("chatMessage-\(message.id)")
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0 ..< 3) { index in
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer(minLength: 60)
        }
        .onAppear { animating = true }
        .accessibilityLabel("Thinking...")
        .accessibilityIdentifier("TypingIndicator")
    }
}

// MARK: - Input Bar

private struct ChatInputBar: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask about your vault...", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1 ... 4)
                .disabled(isSending)
                .accessibilityIdentifier("ChatInput")
                .onSubmit {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .accessibilityLabel("Send")
            .accessibilityIdentifier("SendButton")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}
