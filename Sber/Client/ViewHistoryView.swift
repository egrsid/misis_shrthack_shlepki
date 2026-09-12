import SwiftUI

/// The client's own viewing history, stored per user on the backend.
///
/// Two clients on the same device see different lists: the records are keyed by
/// the account id returned at login, not by anything cached in the app.
struct ViewHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var records: [ProductViewRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isClearing = false
    @State private var selectedProduct: Product?

    private var userId: Int { AuthStore.shared.currentUserId }

    var body: some View {
        ZStack {
            AppGradientBackground()

            VStack(spacing: 0) {
                if API.useMock { MockBanner() }
                header

                if let errorMessage, records.isEmpty {
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
                } else if records.isEmpty && !isLoading {
                    emptyState
                } else {
                    list
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task { await load() }
        .navigationDestination(item: $selectedProduct) { product in
            ProductDetailView(product: product)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
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

                Text("История просмотров")
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

            if let login = AuthStore.shared.currentUser?.login {
                Text("Аккаунт: \(login)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if let errorMessage {
                    ErrorStrip(message: errorMessage, onRetry: { Task { await load() } })
                }

                ForEach(records) { record in
                    Button {
                        selectedProduct = Product.named(record.productId)
                    } label: {
                        HistoryRow(record: record)
                    }
                    .buttonStyle(.plain)
                    .disabled(Product.named(record.productId) == nil)
                }

                Button {
                    Task { await clear() }
                } label: {
                    Text(isClearing ? "Очищаем…" : "Очистить историю")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .underline()
                }
                .disabled(isClearing)
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.8))
            Text("Вы пока ничего не смотрели")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            Text("Откройте любой товар в каталоге — он появится здесь.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            records = try await APIClient.shared.views(forUser: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func clear() async {
        isClearing = true
        errorMessage = nil
        do {
            try await APIClient.shared.clearViews(forUser: userId)
            records = []
        } catch {
            errorMessage = error.localizedDescription
        }
        isClearing = false
    }
}

private struct HistoryRow: View {
    let record: ProductViewRecord

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.pantone349.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: Product.named(record.productId)?.imageName ?? "cube.box")
                    .font(.system(size: 18))
                    .foregroundColor(.pantone349)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(record.productName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(secondLine)
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.5))
            }

            Spacer(minLength: 4)

            if let price = record.price {
                Text("\(price) ₽")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.pantone349)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(14)
    }

    private var secondLine: String {
        var parts = [Self.relativeFormatter.localizedString(for: record.lastViewedAt, relativeTo: Date())]
        if record.viewsCount > 1 {
            parts.append("\(record.viewsCount) \(viewWord(record.viewsCount))")
        }
        return parts.joined(separator: " · ")
    }

    private func viewWord(_ count: Int) -> String {
        switch count % 10 {
        case 1 where count % 100 != 11: return "просмотр"
        case 2, 3, 4 where !(11...14).contains(count % 100): return "просмотра"
        default: return "просмотров"
        }
    }
}
