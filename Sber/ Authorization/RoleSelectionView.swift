import SwiftUI

struct RoleSelectionView: View {
    @ObservedObject private var auth = AuthStore.shared

    var body: some View {
        NavigationStack {
            AuthBackground {
                Text("Кто вы?")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)

                VStack(spacing: 16) {
                    NavigationLink {
                        OperatorLoginView()
                    } label: {
                        RoleOptionLabel(title: "Оператор")
                    }

                    NavigationLink {
                        ClientLoginView()
                    } label: {
                        RoleOptionLabel(title: "Клиент")
                    }
                }
            }
        }
        // Signing out changes the session id, which rebuilds the stack and brings
        // the app back here with nothing left over from the previous account.
        .id(auth.sessionId)
    }
}

private struct RoleOptionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.pantone349)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
    }
}

#Preview {
    RoleSelectionView()
}
