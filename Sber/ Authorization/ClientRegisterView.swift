import SwiftUI

struct ClientRegisterView: View {
    @State private var login: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var passwordContentType: UITextContentType? = .newPassword
    @State private var isRegistered = false
    @State private var isWorking = false

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

            AuthPrimaryButton(title: isWorking ? "Создаём аккаунт…" : "Зарегистрироваться") {
                Task { await handleRegister() }
            }
            .disabled(isWorking)
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

    /// The account is created on the backend: the login and the hashed password
    /// are stored there, so it still exists after the app is restarted.
    private func handleRegister() async {
        isWorking = true
        errorMessage = nil
        do {
            _ = try await AuthStore.shared.register(
                login: login,
                email: email,
                password: password
            )
            passwordContentType = .newPassword
            isRegistered = true
        } catch {
            errorMessage = error.localizedDescription
            passwordContentType = .oneTimeCode
        }
        isWorking = false
    }
}

#Preview {
    NavigationStack {
        ClientRegisterView()
    }
}
