import SwiftUI

enum CatalogSection: String, CaseIterable, Identifiable {
    case products = "Товары"
    case orders = "Мои заказы"
    case supportRequests = "Запросы в поддержку"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .products: return "bag.fill"
        case .orders: return "shippingbox.fill"
        case .supportRequests: return "bubble.left.and.exclamationmark.bubble.right.fill"
        }
    }
}

struct SideMenuView: View {
    @Binding var isPresented: Bool
    let onSelect: (CatalogSection) -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(alignment: .leading, spacing: 8) {
                Text("Каталог")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.pantone349)
                    .padding(.top, 60)
                    .padding(.bottom, 16)

                ForEach(CatalogSection.allCases) { section in
                    Button {
                        onSelect(section)
                        close()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: section.icon)
                                .font(.system(size: 18))
                                .foregroundColor(.pantone349)
                                .frame(width: 24)

                            Text(section.rawValue)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)

                            Spacer()
                        }
                        .padding(.vertical, 14)
                    }

                    Divider()
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(width: 260)
            .frame(maxHeight: .infinity)
            .background(Color.white)
            .shadow(color: .black.opacity(0.15), radius: 12, x: -4)
        }
    }

    private func close() {
        isPresented = false
    }
}

#Preview {
    SideMenuView(isPresented: .constant(true)) { _ in }
}
