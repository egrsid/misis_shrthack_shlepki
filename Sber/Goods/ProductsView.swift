import SwiftUI

private let productCardHeight: CGFloat = 200

struct ProductsView: View {
    @State private var isSupportPresented = false

    private let columns = [
        GridItem(.flexible(), spacing: 28),
        GridItem(.flexible())
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppGradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Товары")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 16)

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
