import SwiftUI

/// The client's chat.
///
/// A request only reaches the operator once it is complete: the first message is
/// analysed, and while any issue in it is still missing required fields the chat
/// keeps asking and sends the answers to /requests/{id}/clarify.
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

    /// Set while the current request still has issues waiting for data.
    @State private var pendingRequestId: String?
    @State private var pendingIssues: [Issue] = []
    /// Counts answers that produced nothing, to offer a way out of a loop.
    @State private var fruitlessAnswers = 0
    @State private var showHistory = false

    @StateObject private var dictation = SpeechDictation()
    /// What the client had typed before dictation started, so speech is appended
    /// instead of wiping their text.
    @State private var dictationPrefix = ""

    private var userId: Int { AuthStore.shared.currentUserId }

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

                            if isSending { TypingIndicator() }

                            if let errorMessage {
                                ErrorStrip(
                                    message: errorMessage,
                                    onRetry: lastFailedText == nil ? nil : { retry() },
                                    onUseMock: { enableMockAndRetry() }
                                )
                            }

                            // Escape hatch: a client who cannot find the serial
                            // number must not be stuck in the chat forever.
                            if fruitlessAnswers >= 2, !pendingIssues.isEmpty, !isSending {
                                sendAnywayButton
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
        // Recognised speech goes into the editable field, never straight to the
        // backend: the client checks it first.
        .onChange(of: dictation.transcript) {
            draft = dictationPrefix + dictation.transcript
        }
        .onDisappear { dictation.stop() }
        .navigationDestination(isPresented: $showHistory) {
            SupportRequestsView(openedFromChat: true)
        }
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

            VStack(spacing: 2) {
                Text("Чат с поддержкой")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                if !pendingIssues.isEmpty {
                    Text("Ждём данные для оформления")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            Spacer()

            // History belongs next to the conversation it is about, not in the
            // store catalogue.
            Button {
                showHistory = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                    Text("История")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.pantone349)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.white)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if let message = dictation.errorMessage {
                hintLine(message, isError: true)
            } else if dictation.isRecording {
                hintLine("Говорите… текст появится в поле, его можно поправить перед отправкой", isError: false)
            }

            HStack(spacing: 10) {
                if dictation.isSupported { micButton }

                TextField(inputPlaceholder, text: $draft, axis: .vertical)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(20)
                    // Read-only while dictating, otherwise typing and recognition
                    // would fight over the same string.
                    .disabled(isSending || dictation.isRecording)

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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var micButton: some View {
        Button {
            Task { await toggleDictation() }
        } label: {
            Image(systemName: dictation.isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(dictation.isRecording ? .white : .pantone349)
                .frame(width: 42, height: 42)
                .background(dictation.isRecording ? Color.missingRed : Color.white)
                .clipShape(Circle())
        }
        .disabled(isSending)
    }

    private func hintLine(_ text: String, isError: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isError ? "exclamationmark.circle" : "waveform")
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.leading)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isError ? Color.red.opacity(0.8) : Color.white.opacity(0.2))
        .cornerRadius(10)
    }

    private var inputPlaceholder: String {
        if dictation.isRecording { return "Слушаю…" }
        return pendingIssues.isEmpty ? "Опишите проблему" : "Ответьте на вопрос выше"
    }

    private var sendAnywayButton: some View {
        Button {
            Task { await submitAnyway() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "paperplane")
                Text("Не могу найти эти данные — передать оператору как есть")
                    .multilineTextAlignment(.leading)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.pantone349)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Actions

    /// Starts or stops dictation, appending speech to whatever is already typed.
    private func toggleDictation() async {
        if dictation.isRecording {
            dictation.stop()
            return
        }
        let typed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        dictationPrefix = typed.isEmpty ? "" : typed + " "
        await dictation.start()
    }

    private func send() {
        dictation.stop()
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(sender: .user, text: text))
        draft = ""
        submit(text)
    }

    private func retry() {
        guard let text = lastFailedText else { return }
        submit(text)
    }

    private func enableMockAndRetry() {
        API.useMock = true
        if lastFailedText != nil {
            retry()
        } else {
            errorMessage = nil
        }
    }

    /// Routes the message: a new request goes to /analyze, an answer to a pending
    /// one goes to /clarify.
    private func submit(_ text: String) {
        isSending = true
        errorMessage = nil

        Task {
            do {
                let response: AnalyzeResponse
                if let requestId = pendingRequestId {
                    response = try await APIClient.shared.clarify(requestId: requestId, text: text)
                } else {
                    response = try await APIClient.shared.analyze(userId: userId, text: text)
                }
                lastFailedText = nil
                apply(response)
            } catch {
                lastFailedText = text
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }

    private func apply(_ response: AnalyzeResponse) {
        let wasWaiting = !pendingIssues.isEmpty
        let stillPending = response.pendingIssues

        // Tell the client what actually went to an operator.
        if !response.submittedIssues.isEmpty {
            messages.append(ChatMessage(
                sender: .assistant,
                text: submittedText(for: response.submittedIssues)
            ))
        }

        // And ask, in one message, for everything that is still missing.
        if let clarification = response.clarification {
            messages.append(ChatMessage(sender: .assistant, text: clarification))
        }

        // An answer that moved nothing forward: count it, so the way out appears.
        if response.submittedIssues.isEmpty {
            if wasWaiting { fruitlessAnswers += 1 }
        } else {
            fruitlessAnswers = 0
        }

        pendingIssues = stillPending
        pendingRequestId = stillPending.isEmpty ? nil : response.requestId

        if stillPending.isEmpty, response.submittedIssues.isEmpty {
            messages.append(ChatMessage(
                sender: .assistant,
                text: "Спасибо! Обращение передано оператору."
            ))
        }
    }

    private func submittedText(for issues: [Issue]) -> String {
        let titles = issues.map { "• \($0.title)" }.joined(separator: "\n")
        let tail = "\n\nОтвет появится здесь же, по кнопке «История» наверху."
        if issues.count == 1 {
            return "Готово, передал оператору:\n\(titles)" + tail
        }
        return "Готово, передал оператору \(issues.count) \(issueWord(issues.count)):\n\(titles)" + tail
    }

    /// Submits the pending issues without the data the client cannot provide.
    private func submitAnyway() async {
        isSending = true
        errorMessage = nil
        var sent: [Issue] = []

        for issue in pendingIssues {
            do {
                let updated = try await APIClient.shared.update(
                    issueId: issue.id,
                    patch: IssuePatch(status: .new)
                )
                sent.append(updated)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        isSending = false

        guard !sent.isEmpty else { return }
        pendingIssues = []
        pendingRequestId = nil
        fruitlessAnswers = 0
        messages.append(ChatMessage(
            sender: .assistant,
            text: "Передал оператору без этих данных — он свяжется с вами, если они понадобятся."
        ))
    }

    private func issueWord(_ count: Int) -> String {
        switch count % 10 {
        case 1 where count % 100 != 11: return "заявку"
        case 2, 3, 4 where !(11...14).contains(count % 100): return "заявки"
        default: return "заявок"
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
