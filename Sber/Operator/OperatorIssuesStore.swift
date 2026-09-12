import Foundation

/// The two lists an operator works with. Answered issues are deliberately kept
/// out of the main queue — they are done, and leaving them there is what made the
/// feed hard to read.
enum OperatorFeedTab: String, CaseIterable, Identifiable {
    case active
    case answered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: return "В работе"
        case .answered: return "Отвеченные"
        }
    }
}

/// Single source of truth for the operator's feed and card.
///
/// The detail screen reads its issue out of here by id, so a saved slot or a sent
/// reply updates the feed behind it without a reload.
@MainActor
final class OperatorIssuesStore: ObservableObject {
    @Published private(set) var issues: [Issue] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var tab: OperatorFeedTab = .active
    @Published var categoryFilter: IssueCategory?
    @Published var priorityFilter: IssuePriority?

    private let client = APIClient.shared

    /// Oldest first in the queue: the request that has been waiting longest is the
    /// one to answer next. Answered issues are listed most recent first instead.
    var filteredIssues: [Issue] {
        issues
            .filter { issue in
                guard issue.isDone == (tab == .answered) else { return false }
                if let categoryFilter, issue.category != categoryFilter { return false }
                if let priorityFilter, issue.priority != priorityFilter { return false }
                return true
            }
            .sorted { left, right in
                if tab == .answered {
                    return left.updatedAt > right.updatedAt
                }
                if left.createdAt != right.createdAt {
                    return left.createdAt < right.createdAt
                }
                return left.id < right.id
            }
    }

    var hasActiveFilters: Bool {
        categoryFilter != nil || priorityFilter != nil
    }

    var activeCount: Int { issues.filter { !$0.isDone }.count }
    var answeredCount: Int { issues.filter(\.isDone).count }

    /// Issues an operator has to chase data for: submitted, but with gaps. Happens
    /// when a client sent a request without the fields they could not provide.
    var withGapsCount: Int {
        issues.filter { !$0.isDone && $0.isBlocked }.count
    }

    func issue(id: Int) -> Issue? {
        issues.first { $0.id == id }
    }

    func clearFilters() {
        categoryFilter = nil
        priorityFilter = nil
    }

    // MARK: Backend calls

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            issues = try await client.allIssues()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func enableMockAndReload() async {
        API.useMock = true
        await load()
    }

    /// Saves edited fields. Returns false so the caller can keep the sheet open.
    @discardableResult
    func update(issueId: Int, patch: IssuePatch) async -> Bool {
        errorMessage = nil
        do {
            let updated = try await client.update(issueId: issueId, patch: patch)
            replace(updated)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func generateReply(issueId: Int) async -> Bool {
        errorMessage = nil
        do {
            let envelope = try await client.generateReply(issueId: issueId)
            replace(envelope.issue)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func sendReply(issueId: Int, text: String) async -> Bool {
        errorMessage = nil
        do {
            let envelope = try await client.sendReply(issueId: issueId, text: text)
            replace(envelope.issue)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func replace(_ issue: Issue) {
        if let index = issues.firstIndex(where: { $0.id == issue.id }) {
            issues[index] = issue
        } else {
            issues.insert(issue, at: 0)
        }
    }
}

extension Issue {
    var isDone: Bool {
        status == .resolved || status == .closed
    }
}
