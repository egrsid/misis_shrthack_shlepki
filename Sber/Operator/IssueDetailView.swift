import SwiftUI

/// The issue card the operator actually works in.
///
/// Reads the issue out of the store by id, so every save is reflected here and in
/// the feed at once, with no second copy of the state to keep in sync.
struct IssueDetailView: View {
    @ObservedObject var store: OperatorIssuesStore
    let issueId: Int

    @Environment(\.dismiss) private var dismiss

    @State private var replyText: String = ""
    @State private var slotDrafts: [String: String] = [:]
    @State private var isWorking = false
    @State private var isDrafting = false
    @State private var didLoadDraft = false
    /// The draft exactly as the model wrote it. Used to tell an untouched draft
    /// from one the operator has edited, so their wording is never overwritten.
    @State private var generatedSnapshot = ""
    @State private var toast: String?

    private var issue: Issue? { store.issue(id: issueId) }

    var body: some View {
        ZStack {
            AppGradientBackground()

            if let issue {
                content(for: issue)
            } else {
                Text("Заявка не найдена")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task { await prepareDraft() }
    }

    private func content(for issue: Issue) -> some View {
        VStack(spacing: 0) {
            if API.useMock { MockBanner() }
            header(for: issue)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let message = store.errorMessage {
                        ErrorStrip(message: message)
                    }
                    if let toast {
                        successStrip(toast)
                    }

                    originalMessageCard(for: issue)
                    breakdownCard(for: issue)
                    if !issue.missingFields.isEmpty {
                        missingCard(for: issue)
                    }
                    replyCard(for: issue)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: Header

    private func header(for issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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

                if let badge = issue.groupBadge {
                    Text("Заявка \(badge) из одного обращения")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            Text(issue.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: Cards

    /// The operator must be able to check the analysis against what the customer
    /// actually wrote, so the raw message is shown in full.
    private func originalMessageCard(for issue: Issue) -> some View {
        Card(title: "Обращение клиента", iconName: "text.bubble") {
            Text(issue.originalText)
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func breakdownCard(for issue: Issue) -> some View {
        Card(title: "Разбор", iconName: "square.stack.3d.up") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    IssueBadge(
                        text: issue.category.title,
                        color: .pantone349,
                        iconName: issue.category.iconName
                    )
                    IssueBadge(text: issue.priority.title, color: issue.priority.color)
                    IssueBadge(text: issue.status.title, color: issue.status.color, filled: false)
                }

                Text(issue.description)
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)

                if !issue.orderedSlots.isEmpty {
                    Divider()
                    ForEach(issue.orderedSlots, id: \.field.id) { entry in
                        HStack(alignment: .top) {
                            Text(entry.field.title)
                                .font(.system(size: 13))
                                .foregroundColor(.black.opacity(0.5))
                            Spacer()
                            if let value = entry.value, !value.isEmpty {
                                Text(value)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.trailing)
                            } else {
                                Text("не указано")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.missingRed)
                            }
                        }
                    }
                }
            }
        }
    }

    /// The loudest element on the screen: what the case brief asks the system to find.
    private func missingCard(for issue: Issue) -> some View {
        Card(title: "Не хватает данных", iconName: "exclamationmark.triangle.fill", accent: .missingRed) {
            VStack(alignment: .leading, spacing: 12) {
                // An issue only reaches the operator with gaps when the client said
                // they could not provide the data, so the wording says exactly that.
                Text("Для категории «\(issue.category.title)» эти поля обязательны, но клиент не смог их указать. Заполните, когда получите данные.")
                    .font(.system(size: 13))
                    .foregroundColor(.black.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(issue.missingFields) { field in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(field.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.missingRed)
                        TextField("Введите \(field.prompt)", text: binding(for: field))
                            .font(.system(size: 14))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.missingRed.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.missingRed.opacity(0.45), lineWidth: 1)
                            )
                            .cornerRadius(10)
                    }
                }

                Button {
                    Task { await saveSlots(for: issue) }
                } label: {
                    Text("Сохранить данные")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(hasSlotInput ? Color.missingRed : Color.missingRed.opacity(0.4))
                        .cornerRadius(12)
                }
                .disabled(!hasSlotInput || isWorking)
            }
        }
    }

    private func replyCard(for issue: Issue) -> some View {
        Card(title: "Ответ клиенту", iconName: "pencil.and.outline") {
            VStack(alignment: .leading, spacing: 12) {
                // The draft is written as soon as the card opens; the operator's
                // job is to read and correct it, not to ask for it.
                if isDrafting {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Готовим черновик ответа…")
                            .font(.system(size: 13))
                            .foregroundColor(.black.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, minHeight: 130)
                    .background(Color.black.opacity(0.04))
                    .cornerRadius(12)
                } else {
                    // Nothing is sent without the operator reading it: the draft is
                    // editable text, not a preview.
                    TextEditor(text: $replyText)
                        .font(.system(size: 14))
                        .frame(minHeight: 130)
                        .padding(8)
                        .background(Color.black.opacity(0.04))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )

                    Text(issue.generatedReply == nil
                         ? "Черновик не удалось подготовить — напишите ответ сами."
                         : "Черновик подготовлен ИИ. Проверьте и при необходимости поправьте.")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task { await sendReply() }
                } label: {
                    Text(isWorking ? "Отправляем…" : "Подтвердить и отправить")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSend ? Color.pantone349 : Color.pantone349.opacity(0.4))
                        .cornerRadius(12)
                }
                .disabled(!canSend || isWorking)

                Button {
                    Task { await reject() }
                } label: {
                    Text("Отклонить заявку")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.missingRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .disabled(isWorking)

                if let finalReply = issue.finalReply {
                    Divider()
                    Text("Отправлено клиенту:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black.opacity(0.5))
                    Text(finalReply)
                        .font(.system(size: 13))
                        .foregroundColor(.black.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func successStrip(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
            Text(text).font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 30 / 255, green: 140 / 255, blue: 95 / 255))
        .cornerRadius(12)
    }

    // MARK: State helpers

    private var hasSlotInput: Bool {
        slotDrafts.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var canSend: Bool {
        !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func binding(for field: SlotField) -> Binding<String> {
        Binding(
            get: { slotDrafts[field.rawValue] ?? "" },
            set: { slotDrafts[field.rawValue] = $0 }
        )
    }

    /// Fills the editor once, asking the model for a draft if there is none yet.
    ///
    /// Runs once per screen, so a re-render never overwrites the operator's typing.
    /// A failure here is not fatal: the editor simply stays empty to type into.
    private func prepareDraft() async {
        guard !didLoadDraft, let issue else { return }
        didLoadDraft = true

        if !issue.replyDraft.isEmpty {
            replyText = issue.replyDraft
            generatedSnapshot = issue.finalReply == nil ? replyText : ""
            return
        }

        await regenerate()
    }

    /// Asks the model for a draft and puts it in the editor.
    private func regenerate() async {
        isDrafting = true
        await store.generateReply(issueId: issueId)
        isDrafting = false
        replyText = store.issue(id: issueId)?.replyDraft ?? ""
        generatedSnapshot = replyText
    }

    // MARK: Actions

    private func saveSlots(for issue: Issue) async {
        let filled = slotDrafts.compactMapValues { value -> String? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard !filled.isEmpty else { return }

        isWorking = true
        let patch = IssuePatch(slots: filled.mapValues { Optional($0) })
        let ok = await store.update(issueId: issueId, patch: patch)
        isWorking = false

        guard ok else { return }
        slotDrafts = [:]
        showToast("Данные сохранены, список недостающих полей пересчитан")

        // The old draft asked for fields that are now filled in. Rewrite it —
        // unless the operator has already put their own wording in.
        if replyText == generatedSnapshot {
            await regenerate()
        }
    }

    private func sendReply() async {
        isWorking = true
        let ok = await store.sendReply(issueId: issueId, text: replyText)
        isWorking = false
        if ok { showToast("Ответ отправлен клиенту, заявка решена") }
    }

    private func reject() async {
        isWorking = true
        let ok = await store.update(issueId: issueId, patch: IssuePatch(status: .closed))
        isWorking = false
        if ok { showToast("Заявка закрыта без ответа") }
    }

    private func showToast(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            toast = nil
        }
    }
}

/// White rounded block with a titled header, used for every section of the card.
private struct Card<Content: View>: View {
    let title: String
    let iconName: String
    var accent: Color = .pantone349
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(accent)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
    }
}
