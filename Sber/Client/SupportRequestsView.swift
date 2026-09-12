import SwiftUI

/// The client's own requests: what was submitted, where each one stands, and the
/// operator's answer once it has been approved and sent.
struct SupportRequestsView: View {
    /// When opened from the chat, "answer in chat" goes back instead of pushing a
    /// second chat on top of the first one.
    var openedFromChat: Bool = false

    @Environment(\.dismiss) private var dismiss

    @State private var issues: [Issue] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var openChat = false

    private var userId: Int { MockAuthStore.shared.currentClientId }

    /// Newest first, and anything still waiting on the client goes to the top —
    /// that is the only thing here they can act on.
    private var sortedIssues: [Issue] {
        issues.sorted { left, right in
            if left.isCollecting != right.isCollecting { return left.isCollecting }
            return left.id > right.id
        }
    }

    var body: some View {
        ZStack {
            AppGradientBackground()

            VStack(spacing: 0) {
                if API.useMock { MockBanner() }
                header

                if let errorMessage, issues.isEmpty {
                    ErrorStrip(
                        message: errorMessage,
                        onRetry: { Task { await load() } },
                        onUseMock: {
                            API.useMock = true
                            Task { await load() }
                        }
                    )
                    .padding(16)
                    Spacer()
                } else if issues.isEmpty && !isLoading {
                    emptyState
                } else {
                    list
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task { await load() }
        .navigationDestination(isPresented: $openChat) {
            SupportChatView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
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

                Text("Запросы в поддержку")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
                .disabled(isLoading)
            }

            if waitingCount > 0 {
                Text("\(waitingCount) \(requestWord(waitingCount)) ждут ваших данных")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var waitingCount: Int {
        issues.filter(\.isCollecting).count
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let errorMessage {
                    ErrorStrip(message: errorMessage, onRetry: { Task { await load() } })
                }

                ForEach(sortedIssues) { issue in
                    RequestCard(
                        issue: issue,
                        answerTitle: openedFromChat ? "Вернуться в чат" : "Ответить в чате",
                        onAnswer: goToChat
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.8))
            Text("Запросов пока нет")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            Text("Напишите в поддержку — обращение появится здесь вместе со статусом и ответом.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            Button(action: goToChat) {
                Text(openedFromChat ? "Вернуться в чат" : "Написать в поддержку")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.pantone349)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    /// Back to the chat the client came from, or into a new one.
    private func goToChat() {
        if openedFromChat {
            dismiss()
        } else {
            openChat = true
        }
    }

    private func requestWord(_ count: Int) -> String {
        switch count % 10 {
        case 1 where count % 100 != 11: return "запрос"
        case 2, 3, 4 where !(11...14).contains(count % 100): return "запроса"
        default: return "запросов"
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            issues = try await APIClient.shared.issues(forUser: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

/// One request as the client sees it.
private struct RequestCard: View {
    let issue: Issue
    let answerTitle: String
    let onAnswer: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                IssueBadge(
                    text: issue.category.title,
                    color: .pantone349,
                    iconName: issue.category.iconName,
                    filled: false
                )

                Spacer()

                IssueBadge(text: issue.clientStatusTitle, color: issue.clientStatusColor)
            }

            Text(issue.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)

            Text(Self.dateFormatter.string(from: issue.createdAt))
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.45))

            // Still waiting on the client: say exactly what is needed and how to give it.
            if issue.isCollecting, !issue.missingFields.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Не хватает: " + issue.missingFields.map(\.title).joined(separator: ", "))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.missingRed)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: onAnswer) {
                        Text(answerTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.pantone349)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.missingRed.opacity(0.07))
                .cornerRadius(10)
            }

            if let answer = issue.finalReply {
                Divider()
                Text("Ответ поддержки")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.pantone349)
                Text(answer)
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            } else if !issue.isCollecting {
                Text("Оператор изучает обращение — ответ появится здесь.")
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
    }
}
