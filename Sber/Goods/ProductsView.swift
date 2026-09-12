import SwiftUI

private let productCardWidth: CGFloat = 160
private let productCardHeight: CGFloat = 170

struct ProductsView: View {
    @State private var isSupportPresented = false

    private let columns = [GridItem(.adaptive(minimum: productCardWidth, maximum: productCardWidth), spacing: 28)]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppGradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center) {
                        Text("Товары")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()

                        // Labelled on purpose: a bare grid icon in the corner does
                        // not tell anyone it opens the catalogue.
                        NavigationLink {
                            CatalogueView()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Каталог")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.pantone349)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 16)

                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(mockProducts) { product in
                            // Opening a product is what records it in this
                            // client's viewing history.
                            NavigationLink {
                                ProductDetailView(product: product)
                            } label: {
                                ProductCard(product: product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 100)
            }

            Button {
                isSupportPresented = true
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
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $isSupportPresented) {
            SupportChatView()
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
                    .frame(width: 72, height: 72)

                Image(systemName: product.imageName)
                    .font(.system(size: 30))
                    .foregroundColor(.pantone349)
            }

            Text(product.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 36, alignment: .top)

            Text("\(product.price) ₽")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.pantone349)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: productCardWidth, height: productCardHeight)
        .background(Color.white)
        .cornerRadius(16)
    }
}

#Preview {
    NavigationStack {
        ProductsView()
    }
}
