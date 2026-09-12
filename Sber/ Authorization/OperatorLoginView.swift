import SwiftUI

struct OperatorLoginView: View {
    @State private var login: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var passwordContentType: UITextContentType? = .password
    @State private var isAuthenticated = false

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

            AuthPrimaryButton(title: "Войти") {
                handleLogin()
            }
        }
        .onDisappear {
            if errorMessage != nil {
                password = ""
            }
        }
        .navigationDestination(isPresented: $isAuthenticated) {
            HomePlaceholderView(title: "Добро пожаловать, оператор!")
        }
    }

    private func handleLogin() {
        guard MockAuthStore.shared.loginOperator(login: login, password: password) else {
            errorMessage = "Неверный логин или пароль"
            passwordContentType = .oneTimeCode
            return
        }
        errorMessage = nil
        passwordContentType = .password
        isAuthenticated = true
    }
}

#Preview {
    NavigationStack {
        OperatorLoginView()
    }
}
