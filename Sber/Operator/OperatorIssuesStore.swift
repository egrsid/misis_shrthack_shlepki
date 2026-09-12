import Foundation

/// Single source of truth for the operator's feed and card.
///
/// The detail screen reads its issue out of here by id, so a saved slot or a sent
/// reply updates the feed behind it without a reload.
@MainActor
final class OperatorIssuesStore: ObservableObject {
    @Published private(set) var issues: [Issue] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var statusFilter: IssueStatus?
    @Published var categoryFilter: IssueCategory?
    @Published var priorityFilter: IssuePriority?

    private let client = APIClient.shared

    /// Open work first, then the most dangerous, then the newest — an operator
    /// should meet a `critical` safety issue at the top of the list.
    var filteredIssues: [Issue] {
        issues
            .filter { issue in
                if let statusFilter, issue.status != statusFilter { return false }
                if let categoryFilter, issue.category != categoryFilter { return false }
                if let priorityFilter, issue.priority != priorityFilter { return false }
                return true
            }
            .sorted { left, right in
                if left.isDone != right.isDone { return !left.isDone }
                if left.priority.rank != right.priority.rank {
                    return left.priority.rank < right.priority.rank
                }
                return left.id > right.id
            }
    }

    var hasActiveFilters: Bool {
        statusFilter != nil || categoryFilter != nil || priorityFilter != nil
    }

    var awaitingInfoCount: Int {
        issues.filter { $0.status == .awaitingInfo }.count
    }

    func issue(id: Int) -> Issue? {
        issues.first { $0.id == id }
    }

    func clearFilters() {
        statusFilter = nil
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
