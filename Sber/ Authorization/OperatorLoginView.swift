import SwiftUI

struct OperatorLoginView: View {
    @State private var login: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var passwordContentType: UITextContentType? = .password
    @State private var isAuthenticated = false
    @State private var isWorking = false

    var body: some View {
        AuthBackground {
            Text("Войти")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 16) {
                AuthField(placeholder: "Логин", text: $login, textContentType: .username)
                    .onChange(of: login) { errorMessage = nil }
                AuthField(placeholder: "Пароль", text: $password, isSecure: true, textContentType: passwordContentType)
                    .onChange(of: password) {
                        errorMessage = nil
                        passwordContentType = .password
                    }
            }

            if let errorMessage {
                AuthErrorBanner(message: errorMessage)
            }

            AuthPrimaryButton(title: isWorking ? "Входим…" : "Войти") {
                Task { await handleLogin() }
            }
            .disabled(isWorking)
        }
        .onDisappear {
            if errorMessage != nil {
                password = ""
            }
        }
        .navigationDestination(isPresented: $isAuthenticated) {
            OperatorIssuesView()
        }
    }

    /// Operator accounts are seeded on the backend and cannot be self-registered;
    /// the role is sent so a client account is refused here.
    private func handleLogin() async {
        isWorking = true
        errorMessage = nil
        do {
            _ = try await AuthStore.shared.signIn(
                login: login,
                password: password,
                role: .operatorRole
            )
            passwordContentType = .password
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
            passwordContentType = .oneTimeCode
        }
        isWorking = false
    }
}

#Preview {
    NavigationStack {
        OperatorLoginView()
    }
}
