import SwiftUI

private let productCardHeight: CGFloat = 200

private enum ProductsRoute: String, Identifiable, Hashable {
    case support
    case orders
    case supportRequests

    var id: String { rawValue }
}

struct ProductsView: View {
    @State private var isMenuOpen = false
    @State private var route: ProductsRoute?

    private let columns = [
        GridItem(.flexible(), spacing: 28),
        GridItem(.flexible())
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppGradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(mockProducts) { product in
                            ProductCard(product: product)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 100)
            }

            Button {
                route = .support
            } label: {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.pantone349)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)

            if isMenuOpen {
                SideMenuView(isPresented: $isMenuOpen) { section in
                    handleSectionSelected(section)
                }
                .transition(.move(edge: .trailing))
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(item: $route) { route in
            switch route {
            case .support:
                SupportChatView()
            case .orders:
                MyOrdersView()
            case .supportRequests:
                SupportRequestsListView()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Товары")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button {
                withAnimation {
                    isMenuOpen = true
                }
            } label: {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.top, 16)
    }

    private func handleSectionSelected(_ section: CatalogSection) {
        switch section {
        case .products:
            break
        case .orders:
            route = .orders
        case .supportRequests:
            route = .supportRequests
        }
    }
}

private struct ProductCard: View {
    let product: Product

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(Color.pantone349.opacity(0.12))
                    .frame(width: 88, height: 88)

                Image(systemName: product.imageName)
                    .font(.system(size: 36))
                    .foregroundColor(.pantone349)
            }

            Text(product.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 42, alignment: .top)

            Text("\(product.price) ₽")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.pantone349)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: productCardHeight)
        .background(Color.white)
        .cornerRadius(16)
    }
}

#Preview {
    NavigationStack {
        ProductsView()
    }
}
