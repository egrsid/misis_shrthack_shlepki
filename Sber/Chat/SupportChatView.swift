import SwiftUI

struct SupportChatView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [ChatMessage] = [
        ChatMessage(
            sender: .assistant,
            text: "Здравствуйте! Опишите, пожалуйста, вашу проблему — я задам уточняющие вопросы и передам обращение оператору."
        )
    ]
    @State private var draft: String = ""
    @State private var collectedProblem: String = ""
    @State private var clarificationCount = 0
    @State private var isResolved = false

    private let clarifyingQuestions = [
        "Уточните, пожалуйста, с каким товаром или заказом связана проблема?",
        "Расскажите чуть подробнее, что именно происходит и когда вы это заметили?"
    ]

    var body: some View {
        ZStack {
            AppGradientBackground()

            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.count) {
                        if let lastId = messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
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
            TextField(isResolved ? "Обращение закрыто" : "Опишите проблему", text: $draft, axis: .vertical)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(20)
                .disabled(isResolved)

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            .disabled(isResolved || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(sender: .user, text: text))
        collectedProblem += (collectedProblem.isEmpty ? "" : " ") + text
        draft = ""

        respond()
    }

    private func respond() {
        if collectedProblem.count < 20 && clarificationCount < clarifyingQuestions.count {
            let question = clarifyingQuestions[clarificationCount]
            clarificationCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                messages.append(ChatMessage(sender: .assistant, text: question))
            }
        } else {
            SupportRequestStore.shared.addRequest(message: collectedProblem)
            isResolved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                messages.append(ChatMessage(
                    sender: .assistant,
                    text: "Спасибо, всё понятно! Ваша проблема передана оператору, он свяжется с вами в ближайшее время."
                ))
            }
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

            if message.sender == .assistant { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    NavigationStack {
        SupportChatView()
    }
}
