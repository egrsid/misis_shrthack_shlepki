import SwiftUI

/// A product page. Opening it is what adds the product to the client's own
/// viewing history — the record is written on the backend, keyed by user id.
struct ProductDetailView: View {
    let product: Product

    @Environment(\.dismiss) private var dismiss
    @State private var openChat = false

    var body: some View {
        ZStack {
            AppGradientBackground()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 16) {
                        card
                        actions
                    }
                    .padding(16)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        // Fire-and-forget: a failed history write must never block the product page.
        .task { try? await APIClient.shared.recordView(userId: AuthStore.shared.currentUserId, product: product) }
        .navigationDestination(isPresented: $openChat) {
            SupportChatView()
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

            Text("Товар")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var card: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.pantone349.opacity(0.12))
                    .frame(width: 130, height: 130)

                Image(systemName: product.imageName)
                    .font(.system(size: 58))
                    .foregroundColor(.pantone349)
            }
            .padding(.top, 8)

            Text(product.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)

            Text("\(product.price) ₽")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.pantone349)

            Text("Официальная гарантия 12 месяцев. Доставка от 1 дня.")
                .font(.system(size: 13))
                .foregroundColor(.black.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(18)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            // A stub: the case is about support, not about checkout.
            Button {
            } label: {
                Text("Купить")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.pantone349)
                    .cornerRadius(12)
            }
            .disabled(true)
            .opacity(0.55)

            Button {
                openChat = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.bubble")
                    Text("Задать вопрос о товаре")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.pantone349)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProductDetailView(product: mockProducts[1])
    }
}
