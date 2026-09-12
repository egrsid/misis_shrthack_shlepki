import SwiftUI

struct ClientRegisterView: View {
    @State private var login: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var passwordContentType: UITextContentType? = .newPassword
    @State private var isRegistered = false

    var body: some View {
        AuthBackground {
            Text("Регистрация")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 16) {
                AuthField(placeholder: "Логин", text: $login, textContentType: .username)
                    .onChange(of: login) { errorMessage = nil }
                AuthField(placeholder: "Почта", text: $email, keyboardType: .emailAddress, textContentType: .emailAddress)
                    .onChange(of: email) { errorMessage = nil }
                AuthField(placeholder: "Пароль", text: $password, isSecure: true, textContentType: passwordContentType)
                    .onChange(of: password) {
                        errorMessage = nil
                        passwordContentType = .newPassword
                    }
            }

            if let errorMessage {
                AuthErrorBanner(message: errorMessage)
            }

            AuthPrimaryButton(title: "Зарегистрироваться") {
                handleRegister()
            }
        }
        .onDisappear {
            if errorMessage != nil {
                password = ""
            }
        }
        .navigationDestination(isPresented: $isRegistered) {
            ProductsView()
        }
    }

    private func handleRegister() {
        if let error = MockAuthStore.shared.registerClient(login: login, email: email, password: password) {
            errorMessage = error.errorDescription
            passwordContentType = .oneTimeCode
            return
        }
        errorMessage = nil
        passwordContentType = .newPassword
        CurrentSession.shared.clientLogin = login
        isRegistered = true
    }
}

#Preview {
    NavigationStack {
        ClientRegisterView()
    }
}
