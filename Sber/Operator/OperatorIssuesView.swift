import SwiftUI

/// The operator's main screen: every issue the triage produced, filterable.
struct OperatorIssuesView: View {
    @StateObject private var store = OperatorIssuesStore()
    @State private var selectedIssueId: Int?

    var body: some View {
        ZStack {
            AppGradientBackground()

            VStack(spacing: 0) {
                if API.useMock { MockBanner() }

                header
                filters

                if let message = store.errorMessage, store.issues.isEmpty {
                    ErrorStrip(
                        message: message,
                        onRetry: { Task { await store.load() } },
                        onUseMock: { Task { await store.enableMockAndReload() } }
                    )
                    .padding(16)
                    Spacer()
                } else if store.issues.isEmpty && !store.isLoading {
                    emptyState
                } else {
                    list
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task { await store.load() }
        .navigationDestination(item: $selectedIssueId) { issueId in
            IssueDetailView(store: store, issueId: issueId)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Заявки")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    Task { await store.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .disabled(store.isLoading)
            }

            // Tells the operator what to do first without opening anything.
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var subtitle: String {
        if store.isLoading && store.issues.isEmpty { return "Загружаем заявки…" }
        let total = store.filteredIssues.count
        let waiting = store.awaitingInfoCount
        if waiting > 0 {
            return "\(total) в списке · \(waiting) ждут данных от клиента"
        }
        return "\(total) в списке"
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if store.hasActiveFilters {
                    FilterChip(title: "Сбросить", isSelected: false) { store.clearFilters() }
                }

                // collecting is excluded: those issues are still in the client's
                // chat and never appear in this feed.
                ForEach(IssueStatus.operatorCases) { status in
                    FilterChip(
                        title: status.title,
                        isSelected: store.statusFilter == status
                    ) {
                        store.statusFilter = store.statusFilter == status ? nil : status
                    }
                }

                Divider().frame(height: 20).overlay(Color.white.opacity(0.4))

                ForEach(IssuePriority.allCases) { priority in
                    FilterChip(
                        title: priority.title,
                        isSelected: store.priorityFilter == priority
                    ) {
                        store.priorityFilter = store.priorityFilter == priority ? nil : priority
                    }
                }

                Divider().frame(height: 20).overlay(Color.white.opacity(0.4))

                ForEach(IssueCategory.allCases) { category in
                    FilterChip(
                        title: category.title,
                        isSelected: store.categoryFilter == category
                    ) {
                        store.categoryFilter = store.categoryFilter == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let message = store.errorMessage {
                    ErrorStrip(message: message, onRetry: { Task { await store.load() } })
                }

                ForEach(store.filteredIssues) { issue in
                    Button {
                        selectedIssueId = issue.id
                    } label: {
                        IssueRow(issue: issue)
                    }
                    .buttonStyle(.plain)
                }

                if store.filteredIssues.isEmpty {
                    Text("Под фильтры ничего не подошло")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable { await store.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.8))
            Text("Заявок пока нет")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            Text("Отправьте обращение из чата клиента — разбор появится здесь.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

/// One card in the feed.
private struct IssueRow: View {
    let issue: Issue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                IssueBadge(
                    text: issue.category.title,
                    color: .pantone349,
                    iconName: issue.category.iconName,
                    filled: false
                )
                IssueBadge(text: issue.priority.title, color: issue.priority.color)
                IssueBadge(text: issue.status.title, color: issue.status.color, filled: false)

                Spacer()

                // Decomposition is the headline feature, so the link back to the
                // original message is always on screen.
                if let badge = issue.groupBadge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.pantone349)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.pantone349.opacity(0.12))
                        .cornerRadius(6)
                }
            }

            Text(issue.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(issue.originalText)
                .font(.system(size: 13))
                .foregroundColor(.black.opacity(0.55))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if !issue.missingFields.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Не хватает: " + issue.missingFields.map(\.title).joined(separator: ", "))
                        .font(.system(size: 12, weight: .semibold))
                        .multilineTextAlignment(.leading)
                }
                .foregroundColor(.missingRed)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
    }
}
