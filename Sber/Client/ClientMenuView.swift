import SwiftUI

/// Menu behind the button in the top-right corner of the client's main screen.
///
/// Only "Запросы в поддержку" is real; search, catalogue and orders are stubs —
/// the case is about triaging support requests, not about building a store.
struct ClientMenuView: View {
    private enum Section: String, Identifiable, Hashable {
        case search
        case catalogue
        case orders
        case requests

        var id: String { rawValue }

        var title: String {
            switch self {
            case .search: return "Поиск"
            case .catalogue: return "Каталог"
            case .orders: return "Мои заказы"
            case .requests: return "Запросы в поддержку"
            }
        }

        var iconName: String {
            switch self {
            case .search: return "magnifyingglass"
            case .catalogue: return "square.grid.2x2"
            case .orders: return "shippingbox"
            case .requests: return "bubble.left.and.text.bubble.right"
            }
        }

        var subtitle: String? {
            switch self {
            case .requests: return "Статусы обращений и ответы поддержки"
            default: return nil
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Section?

    private let sections: [Section] = [.search, .catalogue, .orders, .requests]

    var body: some View {
        ZStack {
            AppGradientBackground()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(sections) { section in
                            Button {
                                selected = section
                            } label: {
                                row(for: section)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(item: $selected) { section in
            switch section {
            case .requests:
                SupportRequestsView()
            default:
                StubSectionView(title: section.title, iconName: section.iconName)
            }
        }
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

            Text("Меню")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func row(for section: Section) -> some View {
        HStack(spacing: 14) {
            Image(systemName: section.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.pantone349)
                .frame(width: 42, height: 42)
                .background(Color.pantone349.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.55))
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black.opacity(0.3))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
    }
}

/// Placeholder for the store sections that are out of scope for the hackathon.
struct StubSectionView: View {
    let title: String
    let iconName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppGradientBackground()

            VStack(spacing: 14) {
                Image(systemName: iconName)
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.85))
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text("Раздел в разработке")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))

                Button {
                    dismiss()
                } label: {
                    Text("Назад")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.pantone349)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 32)
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NavigationStack {
        ClientMenuView()
    }
}
