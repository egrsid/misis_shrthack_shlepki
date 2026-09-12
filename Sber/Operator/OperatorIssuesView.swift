import SwiftUI

/// The operator's main screen: the queue of requests waiting for an answer.
///
/// Deliberately sparse. Answered issues live in their own list, the filters sit in
/// one menu instead of three rows of chips, and a card shows only what helps to
/// pick the next request: how urgent, what about, how long it has been waiting.
struct OperatorIssuesView: View {
    @StateObject private var store = OperatorIssuesStore()
    @State private var selectedIssueId: Int?

    var body: some View {
        ZStack {
            AppGradientBackground()

            VStack(spacing: 0) {
                if API.useMock { MockBanner() }

                header
                tabs

                if let message = store.errorMessage, store.issues.isEmpty {
                    ErrorStrip(
                        message: message,
                        onRetry: { Task { await store.load() } },
                        onUseMock: { Task { await store.enableMockAndReload() } }
                    )
                    .padding(16)
                    Spacer()
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

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                Text("Заявки")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                filterMenu

                Button {
                    Task { await store.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.16))
                        .clipShape(Circle())
                }
                .disabled(store.isLoading)
            }

            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var subtitle: String {
        if store.isLoading && store.issues.isEmpty { return "Загружаем заявки…" }
        if store.tab == .answered {
            return "\(store.answeredCount) отвечено"
        }
        var parts = ["\(store.activeCount) в очереди"]
        if store.withGapsCount > 0 {
            parts.append("\(store.withGapsCount) без данных")
        }
        return parts.joined(separator: " · ")
    }

    /// One button instead of three rows of chips.
    private var filterMenu: some View {
        Menu {
            Picker("Приоритет", selection: $store.priorityFilter) {
                Text("Любой приоритет").tag(IssuePriority?.none)
                ForEach(IssuePriority.allCases) { priority in
                    Text(priority.title).tag(Optional(priority))
                }
            }
            Picker("Категория", selection: $store.categoryFilter) {
                Text("Все категории").tag(IssueCategory?.none)
                ForEach(IssueCategory.allCases) { category in
                    Text(category.title).tag(Optional(category))
                }
            }
            if store.hasActiveFilters {
                Button("Сбросить фильтры", role: .destructive) { store.clearFilters() }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())

                if store.hasActiveFilters {
                    Circle()
                        .fill(Color.priorityHigh)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                }
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            ForEach(OperatorFeedTab.allCases) { tab in
                FilterChip(
                    title: tab == .active
                        ? "\(tab.title) · \(store.activeCount)"
                        : "\(tab.title) · \(store.answeredCount)",
                    isSelected: store.tab == tab
                ) {
                    store.tab = tab
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if let message = store.errorMessage, !store.issues.isEmpty {
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

                if store.filteredIssues.isEmpty && !store.isLoading {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable { await store.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: store.tab == .active ? "tray" : "checkmark.circle")
                .font(.system(size: 34))
                .foregroundColor(.white.opacity(0.75))
            Text(emptyTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            if store.hasActiveFilters {
                Button("Сбросить фильтры") { store.clearFilters() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .underline()
            }
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    private var emptyTitle: String {
        if store.hasActiveFilters { return "Под фильтры ничего не подошло" }
        return store.tab == .active ? "Очередь пуста" : "Отвеченных заявок пока нет"
    }
}

/// One card in the queue: urgency, subject, age. Everything else is in the card.
private struct IssueRow: View {
    let issue: Issue

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            // Priority as a dot: visible at a glance, no capsule to read.
            Circle()
                .fill(issue.priority.color)
                .frame(width: 9, height: 9)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(issue.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 4)

                    // Decomposition stays visible: this issue came out of a
                    // message that held several problems.
                    if let badge = issue.groupBadge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.pantone349)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.pantone349.opacity(0.1))
                            .cornerRadius(5)
                    }
                }

                Text(secondLine)
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.5))

                if issue.isBlocked && !issue.isDone {
                    Text("Не хватает: " + issue.missingFields.map(\.title).joined(separator: ", "))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.missingRed)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(14)
    }

    /// Category, age, and a status only when it is not the default one — a queue
    /// where every card says "Новая" says nothing.
    private var secondLine: String {
        var parts = [issue.category.title]
        if issue.priority == .critical { parts.append("критический") }
        if issue.status != .new { parts.append(issue.status.title.lowercased()) }
        parts.append(Self.relativeFormatter.localizedString(for: issue.createdAt, relativeTo: Date()))
        return parts.joined(separator: " · ")
    }
}
