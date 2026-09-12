import SwiftUI

struct SupportChatView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [ChatMessage] = [
        ChatMessage(
            sender: .assistant,
            text: "Здравствуйте! Опишите, пожалуйста, вашу проблему своими словами — можно сразу несколько вопросов в одном сообщении."
        )
    ]
    @State private var draft: String = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    /// Kept so the retry button can resend the exact text that failed.
    @State private var lastFailedText: String?

    private var userId: Int { MockAuthStore.shared.currentClientId }

    var body: some View {
        ZStack {
            AppGradientBackground()

            VStack(spacing: 0) {
                if API.useMock { MockBanner() }
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }

                            if isSending {
                                TypingIndicator()
                            }

                            if let errorMessage {
                                ErrorStrip(
                                    message: errorMessage,
                                    onRetry: lastFailedText == nil ? nil : { retry() },
                                    onUseMock: { enableMockAndRetry() }
                                )
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.count) {
                        if let lastId = messages.last?.id {
                            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                    }
                }

                inputBar
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
            }

            Spacer()

            Text("Чат с поддержкой")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Опишите проблему", text: $draft, axis: .vertical)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(20)
                .disabled(isSending)

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .opacity(canSend ? 1 : 0.5)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Actions

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(sender: .user, text: text))
        draft = ""
        analyze(text)
    }

    private func retry() {
        guard let text = lastFailedText else { return }
        analyze(text)
    }

    private func enableMockAndRetry() {
        API.useMock = true
        if lastFailedText != nil {
            retry()
        } else {
            errorMessage = nil
        }
    }

    /// One round trip: the backend splits the message, triages every issue and
    /// returns the single clarification covering all the gaps at once.
    private func analyze(_ text: String) {
        isSending = true
        errorMessage = nil

        Task {
            do {
                let response = try await APIClient.shared.analyze(userId: userId, text: text)
                lastFailedText = nil
                SupportRequestStore.shared.record(message: text, issues: response.issues)

                messages.append(ChatMessage(sender: .assistant, text: acknowledgement(for: response)))

                // The clarifying question is the one thing sent to the customer
                // automatically: it promises nothing, so it needs no approval.
                if let clarification = response.clarification {
                    messages.append(ChatMessage(sender: .assistant, text: clarification))
                }
            } catch {
                lastFailedText = text
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }

    private func acknowledgement(for response: AnalyzeResponse) -> String {
        let count = response.issues.count
        let titles = response.issues.map { "• \($0.title)" }.joined(separator: "\n")

        if count == 1 {
            return "Принял обращение и передал оператору:\n\(titles)"
        }
        return "В вашем сообщении я нашёл \(count) \(issueWord(count)) и оформил каждое отдельно:\n\(titles)"
    }

    private func issueWord(_ count: Int) -> String {
        switch count % 10 {
        case 1 where count % 100 != 11: return "обращение"
        case 2, 3, 4 where !(11...14).contains(count % 100): return "обращения"
        default: return "обращений"
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.sender == .user { Spacer(minLength: 40) }

            Text(message.text)
                .font(.system(size: 15))
                .foregroundColor(message.sender == .user ? .white : .black)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.sender == .user ? Color.pantone349 : Color.white)
                .cornerRadius(16)
                .fixedSize(horizontal: false, vertical: true)

            if message.sender == .assistant { Spacer(minLength: 40) }
        }
    }
}

private struct TypingIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7)
            Text("Разбираю обращение…")
                .font(.system(size: 13))
                .foregroundColor(.black.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(16)
    }
}

#Preview {
    NavigationStack {
        SupportChatView()
    }
}
