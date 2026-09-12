import Foundation

// MARK: - Enumerations
// Each one decodes unknown values into a safe default instead of throwing: a new
// category added on the backend must never blank out the operator's feed.

enum IssueCategory: String, Codable, CaseIterable, Identifiable {
    case technical
    case delivery
    case payment
    case yreturn = "return"   // `return` is a Swift keyword
    case warranty
    case accessories
    case productAdvice = "product_advice"
    case accountOrder = "account_order"
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .technical: return "Техника"
        case .delivery: return "Доставка"
        case .payment: return "Оплата"
        case .yreturn: return "Возврат"
        case .warranty: return "Гарантия"
        case .accessories: return "Аксессуары"
        case .productAdvice: return "Подбор"
        case .accountOrder: return "Заказ"
        case .other: return "Прочее"
        }
    }

    var iconName: String {
        switch self {
        case .technical: return "wrench.and.screwdriver.fill"
        case .delivery: return "shippingbox.fill"
        case .payment: return "creditcard.fill"
        case .yreturn: return "arrow.uturn.left"
        case .warranty: return "checkmark.seal.fill"
        case .accessories: return "cable.connector"
        case .productAdvice: return "sparkles"
        case .accountOrder: return "person.text.rectangle"
        case .other: return "questionmark.circle"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = IssueCategory(rawValue: raw) ?? .other
    }
}

enum IssuePriority: String, Codable, CaseIterable, Identifiable {
    case critical
    case high
    case medium
    case low

    var id: String { rawValue }

    var title: String {
        switch self {
        case .critical: return "Критический"
        case .high: return "Высокий"
        case .medium: return "Средний"
        case .low: return "Низкий"
        }
    }

    /// Feed sorting: danger first. Mirrors the backend rule that `critical` means
    /// a safety risk, not an impatient customer.
    var rank: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = IssuePriority(rawValue: raw) ?? .medium
    }
}

enum IssueStatus: String, Codable, CaseIterable, Identifiable {
    /// Still being clarified in the client's chat; deliberately not in the
    /// operator's feed, because an incomplete request is not their work yet.
    case collecting
    case new
    case awaitingInfo = "awaiting_info"
    case inProgress = "in_progress"
    case resolved
    case closed

    var id: String { rawValue }

    /// Wording for the operator.
    var title: String {
        switch self {
        case .collecting: return "Собираем данные"
        case .new: return "Новая"
        case .awaitingInfo: return "Нужны данные"
        case .inProgress: return "В работе"
        case .resolved: return "Решена"
        case .closed: return "Закрыта"
        }
    }

    /// Statuses the operator can actually see, used for the feed filters.
    static var operatorCases: [IssueStatus] {
        allCases.filter { $0 != .collecting }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = IssueStatus(rawValue: raw) ?? .new
    }
}

/// The fields the backend can extract. The order of `allCases` is the display
/// order in the operator's card, so it stays stable between issues.
enum SlotField: String, Codable, CaseIterable, Identifiable {
    case orderId = "order_id"
    case model
    case serialNumber = "serial_number"
    case purchaseDate = "purchase_date"
    case amount
    case reason
    case issue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .orderId: return "Номер заказа"
        case .model: return "Модель"
        case .serialNumber: return "Серийный номер"
        case .purchaseDate: return "Дата покупки"
        case .amount: return "Сумма"
        case .reason: return "Причина возврата"
        case .issue: return "Неисправность"
        }
    }

    /// Wording for the operator asking the customer for this field.
    var prompt: String {
        switch self {
        case .orderId: return "номер заказа"
        case .model: return "модель устройства"
        case .serialNumber: return "серийный номер"
        case .purchaseDate: return "дату покупки"
        case .amount: return "сумму платежа"
        case .reason: return "причину возврата"
        case .issue: return "описание неисправности"
        }
    }
}

// MARK: - Issue

struct Issue: Identifiable, Codable, Equatable, Sendable {
    let id: Int
    let userId: Int
    /// Grows as the client answers clarifying questions, so the operator reads
    /// the whole exchange in one place.
    var originalText: String
    var title: String
    var description: String
    var category: IssueCategory
    var priority: IssuePriority
    var status: IssueStatus
    /// Extracted values; a present key with a nil value means "asked for, not provided".
    var slots: [String: String?]
    /// Computed by the backend rules, never by the model.
    var missing: [String]
    var generatedReply: String?
    var finalReply: String?
    let requestId: String?
    /// "Issue 2 of 3" — the visible proof that one message was split up.
    let groupIndex: Int
    let groupTotal: Int
    let createdAt: Date
    let updatedAt: Date

    /// Slots in a stable display order, unknown keys last.
    var orderedSlots: [(field: SlotField, value: String?)] {
        SlotField.allCases.compactMap { field in
            guard slots.keys.contains(field.rawValue) else { return nil }
            return (field, slots[field.rawValue] ?? nil)
        }
    }

    var missingFields: [SlotField] {
        missing.compactMap { SlotField(rawValue: $0) }
    }

    var isBlocked: Bool { !missing.isEmpty }

    /// Shown on the card when the issue came out of a multi-problem message.
    var groupBadge: String? {
        groupTotal > 1 ? "\(groupIndex) из \(groupTotal)" : nil
    }

    var replyDraft: String {
        finalReply ?? generatedReply ?? ""
    }

    /// True while the request is still being completed in the chat.
    var isCollecting: Bool { status == .collecting }

    /// Wording for the client, who should not see the team's internal statuses.
    var clientStatusTitle: String {
        switch status {
        case .collecting: return "Нужны данные"
        case .new, .awaitingInfo, .inProgress: return "На рассмотрении"
        case .resolved: return "Отвечено"
        case .closed: return finalReply == nil ? "Закрыто" : "Отвечено"
        }
    }

    /// Keys are spelled out instead of using `.convertFromSnakeCase`, because that
    /// strategy also rewrites the keys *inside* `slots` ("serial_number" would
    /// arrive as "serialNumber") and the field lookup would silently stop matching.
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case originalText = "original_text"
        case title
        case description
        case category
        case priority
        case status
        case slots
        case missing
        case generatedReply = "generated_reply"
        case finalReply = "final_reply"
        case requestId = "request_id"
        case groupIndex = "group_index"
        case groupTotal = "group_total"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Request and response payloads

struct AnalyzeRequest: Encodable, Sendable {
    let userId: Int
    let text: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case text
    }
}

struct AnalyzeResponse: Decodable, Sendable {
    let requestId: String
    let issues: [Issue]
    /// One message covering every gap in the whole request; nil when nothing is missing.
    let clarification: String?
    /// Ids handed to the operator by this call. Issues still missing data stay in
    /// the chat until the customer fills the gaps, so they are not listed here.
    let submitted: [Int]

    var submittedIssues: [Issue] {
        issues.filter { submitted.contains($0.id) }
    }

    var pendingIssues: [Issue] {
        issues.filter(\.isCollecting)
    }

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case issues
        case clarification
        case submitted
    }
}

/// Partial update. Only the fields that are set are encoded, which matches the
/// backend's `exclude_unset` behaviour — sending nil never blanks a field.
struct IssuePatch: Encodable, Sendable {
    var title: String? = nil
    var description: String? = nil
    var category: IssueCategory? = nil
    var priority: IssuePriority? = nil
    var status: IssueStatus? = nil
    var slots: [String: String?]? = nil
}

struct ReplyRequest: Encodable, Sendable {
    let text: String
}

/// The customer's answer to a clarifying question.
struct ClarifyRequest: Encodable, Sendable {
    let text: String
}

struct ReplyEnvelope: Decodable, Sendable {
    let issue: Issue
    let reply: String
}
