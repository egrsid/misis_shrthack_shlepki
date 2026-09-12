import Foundation

/// In-memory stand-in for the backend, used when `API.useMock` is on.
///
/// It mirrors the backend's triage rules — required fields per category, missing
/// list, status, one clarification for the whole request — so a demo run offline
/// behaves exactly like a demo run against FastAPI. The app shows a banner
/// whenever this is serving data; nothing here is passed off as a real answer.
actor MockBackend {
    static let shared = MockBackend()

    private var issues: [Issue] = []
    private var nextId = 1

    // Same table as backend_v1/app/core/triage.py.
    private static let required: [IssueCategory: [SlotField]] = [
        .warranty: [.orderId, .model, .serialNumber, .purchaseDate],
        .yreturn: [.orderId, .model, .reason],
        .payment: [.orderId, .amount],
        .delivery: [.orderId],
        .technical: [.model, .issue],
        .accessories: [.model],
        .productAdvice: [],
        .accountOrder: [.orderId],
        .other: [],
    ]

    private static let categoryPhrases: [IssueCategory: String] = [
        .warranty: "Для гарантийного обращения",
        .yreturn: "Для оформления возврата",
        .payment: "По вопросу оплаты",
        .delivery: "По вопросу доставки",
        .technical: "По технической проблеме",
        .accessories: "По вопросу аксессуаров",
        .accountOrder: "По вашему заказу",
        .productAdvice: "Чтобы подобрать товар",
        .other: "По вашему обращению",
    ]

    // MARK: Reads

    /// The operator's feed: issues still being clarified in the chat are excluded.
    func allIssues() -> [Issue] {
        issues.filter { !$0.isCollecting }
    }

    func issues(forUser userId: Int) -> [Issue] {
        issues.filter { $0.userId == userId }
    }

    // MARK: Analyze

    /// Splits a message into the canned demo issues and triages them with the rules.
    func analyze(userId: Int, text: String) -> AnalyzeResponse {
        let requestId = UUID().uuidString
        let drafts = Self.drafts(for: text)
        var created: [Issue] = []

        for (index, draft) in drafts.enumerated() {
            let missing = Self.missingFields(category: draft.category, slots: draft.slots)
            let issue = Issue(
                id: nextId,
                userId: userId,
                originalText: text,
                title: draft.title,
                description: draft.description,
                category: draft.category,
                priority: draft.priority,
                status: missing.isEmpty ? .new : .collecting,
                slots: Self.visibleSlots(category: draft.category, slots: draft.slots),
                missing: missing.map(\.rawValue),
                generatedReply: nil,
                finalReply: nil,
                requestId: requestId,
                groupIndex: index + 1,
                groupTotal: drafts.count,
                createdAt: Date(),
                updatedAt: Date()
            )
            nextId += 1
            created.append(issue)
        }

        issues.insert(contentsOf: created.reversed(), at: 0)
        return AnalyzeResponse(
            requestId: requestId,
            issues: created,
            clarification: Self.clarification(for: created),
            submitted: created.filter { !$0.isCollecting }.map(\.id)
        )
    }

    /// Applies the customer's answer to whatever the request is still waiting for.
    func clarify(requestId: String, text: String) throws -> AnalyzeResponse {
        let indices = issues.indices.filter { issues[$0].requestId == requestId }
        guard !indices.isEmpty else {
            throw APIError.server(status: 404, detail: "Обращение не найдено")
        }
        let pending = indices.filter { issues[$0].isCollecting }
        guard !pending.isEmpty else {
            throw APIError.server(status: 409, detail: "Обращение уже передано оператору")
        }

        let needed = Set(pending.flatMap { issues[$0].missingFields })
        let provided = Self.extractSlots(from: text, needed: needed)

        var submitted: [Int] = []
        for index in pending {
            var issue = issues[index]
            var slots = issue.slots
            // Only the fields this issue asked for.
            for field in issue.missingFields {
                if let value = provided[field] { slots[field.rawValue] = value }
            }
            let typed = slots.reduce(into: [SlotField: String?]()) { result, entry in
                if let field = SlotField(rawValue: entry.key) { result[field] = entry.value }
            }
            let missing = Self.missingFields(category: issue.category, slots: typed)
            issue.slots = Self.visibleSlots(category: issue.category, slots: typed)
            issue.missing = missing.map(\.rawValue)
            issue.status = missing.isEmpty ? .new : .collecting
            issue.originalText += "\n\nУточнение клиента: \(text)"
            issues[index] = issue
            if missing.isEmpty { submitted.append(issue.id) }
        }

        let all = indices.map { issues[$0] }
        return AnalyzeResponse(
            requestId: requestId,
            issues: all,
            clarification: Self.clarification(for: all.filter(\.isCollecting)),
            submitted: submitted
        )
    }

    /// Offline counterpart of the backend's follow-up extraction.
    private static func extractSlots(
        from text: String,
        needed: Set<SlotField>
    ) -> [SlotField: String] {
        var found: [SlotField: String] = [:]
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if needed.contains(.serialNumber) {
            // A serial is the token mixing letters and digits, taken whole.
            let tokens = trimmed.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" })
            if let token = tokens.first(where: { token in
                token.count >= 4 && token.contains(where: \.isLetter)
                    && token.contains(where: \.isNumber)
            }) {
                found[.serialNumber] = String(token)
            }
        }
        if needed.contains(.orderId), let orderId = orderId(in: trimmed) ?? bareNumber(in: trimmed) {
            found[.orderId] = orderId
        }
        if needed.contains(.purchaseDate), let range = trimmed.range(
            of: #"\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4}"#,
            options: .regularExpression
        ) {
            found[.purchaseDate] = String(trimmed[range])
        }
        if needed.contains(.model), let model = device(in: trimmed.lowercased()) {
            found[.model] = model
        }
        for field in [SlotField.reason, .issue] where needed.contains(field) {
            if (3...200).contains(trimmed.count) { found[field] = trimmed }
        }
        return found
    }

    private static func bareNumber(in text: String) -> String? {
        let digits = text.filter(\.isNumber)
        let isOnlyNumber = text.allSatisfy { $0.isNumber || $0.isWhitespace }
        return isOnlyNumber && digits.count >= 3 ? digits : nil
    }

    // MARK: Writes

    func update(issueId: Int, patch: IssuePatch) throws -> Issue {
        guard let index = issues.firstIndex(where: { $0.id == issueId }) else {
            throw APIError.server(status: 404, detail: "Заявка не найдена")
        }
        var issue = issues[index]

        if let title = patch.title { issue.title = title }
        if let description = patch.description { issue.description = description }
        if let category = patch.category { issue.category = category }
        if let priority = patch.priority { issue.priority = priority }

        if let slotChanges = patch.slots {
            for (key, value) in slotChanges {
                issue.slots[key] = Self.clean(value)
            }
        }

        // Recompute exactly like the backend does.
        if patch.slots != nil || patch.category != nil {
            let slots = issue.slots.reduce(into: [SlotField: String?]()) { result, entry in
                if let field = SlotField(rawValue: entry.key) { result[field] = entry.value }
            }
            let missing = Self.missingFields(category: issue.category, slots: slots)
            issue.missing = missing.map(\.rawValue)
            issue.slots = Self.visibleSlots(category: issue.category, slots: slots)
            // Same rule as the backend: only an issue that is still being collected
            // can change side. Once submitted, a new gap is shown to the operator
            // but never hides the issue from the feed again.
            if patch.status == nil, issue.status == .collecting {
                issue.status = missing.isEmpty ? .new : .collecting
            }
        }

        if let status = patch.status { issue.status = status }

        issues[index] = issue
        return issue
    }

    func generateReply(issueId: Int) throws -> ReplyEnvelope {
        guard let index = issues.firstIndex(where: { $0.id == issueId }) else {
            throw APIError.server(status: 404, detail: "Заявка не найдена")
        }
        var issue = issues[index]
        let opening = "Здравствуйте! Мы приняли ваше обращение «\(issue.title)» в работу."
        if issue.missingFields.isEmpty {
            issue.generatedReply = "\(opening) Специалист свяжется с вами в ближайшее время."
        } else {
            let fields = issue.missingFields.map(\.prompt).joined(separator: ", ")
            issue.generatedReply = "\(opening) Чтобы продолжить, укажите, пожалуйста: \(fields). "
                + "Как только получим данные, сразу вернёмся с решением."
        }
        issues[index] = issue
        return ReplyEnvelope(issue: issue, reply: issue.generatedReply ?? "")
    }

    func sendReply(issueId: Int, text: String) throws -> ReplyEnvelope {
        guard let index = issues.firstIndex(where: { $0.id == issueId }) else {
            throw APIError.server(status: 404, detail: "Заявка не найдена")
        }
        var issue = issues[index]
        issue.finalReply = text
        if issue.status != .closed { issue.status = .resolved }
        issues[index] = issue
        return ReplyEnvelope(issue: issue, reply: text)
    }

    // MARK: Rules

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func missingFields(
        category: IssueCategory,
        slots: [SlotField: String?]
    ) -> [SlotField] {
        (required[category] ?? []).filter { clean(slots[$0] ?? nil) == nil }
    }

    private static func visibleSlots(
        category: IssueCategory,
        slots: [SlotField: String?]
    ) -> [String: String?] {
        var keys = required[category] ?? []
        for field in SlotField.allCases where clean(slots[field] ?? nil) != nil {
            if !keys.contains(field) { keys.append(field) }
        }
        return keys.reduce(into: [String: String?]()) { result, field in
            result[field.rawValue] = clean(slots[field] ?? nil)
        }
    }

    private static func clarification(for issues: [Issue]) -> String? {
        var lines: [String] = []
        var seen = Set<String>()

        for issue in issues where !issue.missingFields.isEmpty {
            let key = issue.category.rawValue + issue.missing.joined(separator: ",")
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let labels = issue.missingFields.map(\.prompt)
            let list: String
            if labels.count == 1 {
                list = labels[0]
            } else {
                list = labels.dropLast().joined(separator: ", ") + " и " + labels[labels.count - 1]
            }
            let prefix = categoryPhrases[issue.category] ?? "По вашему обращению"
            lines.append("\(prefix) укажите, пожалуйста: \(list).")
        }

        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    // MARK: Canned split

    private struct Draft {
        let title: String
        let description: String
        let category: IssueCategory
        let priority: IssuePriority
        let slots: [SlotField: String?]
    }

    /// Keyword split, kept close to the backend's offline mode. The demo message
    /// from the script produces the full three-issue breakdown.
    private static func drafts(for text: String) -> [Draft] {
        let lowered = text.lowercased()
        let unsafe = ["дым", "загорел", "возгоран", "искр", "вздул", "запах гари"]
            .contains { lowered.contains($0) }
        var drafts: [Draft] = []

        if ["греет", "нагрев", "не включ", "не работает", "выключа", "зависа", "сломал"]
            .contains(where: lowered.contains) {
            drafts.append(Draft(
                title: "Техническая неисправность",
                description: "Устройство перегревается и самопроизвольно выключается.",
                category: .technical,
                priority: unsafe ? .critical : .high,
                slots: [.model: device(in: lowered), .issue: "перегрев и выключение"]
            ))
        }
        if ["гарант"].contains(where: lowered.contains) {
            drafts.append(Draft(
                title: "Гарантийное обращение",
                description: "Клиент просит ремонт по гарантии.",
                category: .warranty,
                priority: .high,
                slots: [.model: device(in: lowered)]
            ))
        }
        if ["доставк", "не приехал", "не привезли", "где заказ", "посылк"]
            .contains(where: lowered.contains) {
            drafts.append(Draft(
                title: "Вопрос по доставке",
                description: "Заказ не доставлен в срок.",
                category: .delivery,
                priority: .medium,
                slots: [.orderId: orderId(in: text)]
            ))
        }
        if ["возврат", "вернуть"].contains(where: lowered.contains) {
            drafts.append(Draft(
                title: "Запрос на возврат",
                description: "Клиент спрашивает о возврате товара.",
                category: .yreturn,
                priority: .medium,
                slots: [.model: device(in: lowered)]
            ))
        }
        if ["не отвеча", "жалоб", "сколько ждать"].contains(where: lowered.contains) {
            drafts.append(Draft(
                title: "Жалоба на скорость ответа",
                description: "Клиент недоволен временем ожидания ответа поддержки.",
                category: .other,
                priority: .medium,
                slots: [:]
            ))
        }

        if drafts.isEmpty {
            drafts.append(Draft(
                title: "Обращение в поддержку",
                description: text,
                category: .other,
                priority: .medium,
                slots: [:]
            ))
        }
        return drafts
    }

    private static func device(in lowered: String) -> String? {
        let devices = ["ноутбук", "смартфон", "телефон", "планшет", "телевизор", "наушники", "часы"]
        return devices.first { lowered.contains($0) }
    }

    private static func orderId(in text: String) -> String? {
        guard let range = text.range(
            of: #"(?:заказ\w*|order)\D{0,10}(\d{3,})"#,
            options: [.regularExpression, .caseInsensitive]
        ) else { return nil }
        let digits = text[range].filter(\.isNumber)
        return digits.isEmpty ? nil : String(digits)
    }
}
