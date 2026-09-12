import SwiftUI

private enum ClientLoginRoute: Identifiable, Hashable {
    case register
    case home

    var id: Self { self }
}

struct ClientLoginView: View {
    @State private var login: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var passwordContentType: UITextContentType? = .password
    @State private var route: ClientLoginRoute?

    var body: some View {
        AuthBackground {
            Text("Авторизоваться")
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

            Button {
                goToRegister()
            } label: {
                Text("Зарегистрироваться")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .underline()
            }
        }
        .onDisappear {
            if errorMessage != nil {
                password = ""
            }
        }
        .navigationDestination(item: $route) { route in
            switch route {
            case .register:
                ClientRegisterView()
            case .home:
                ProductsView()
            }
        }
    }

    private func handleLogin() {
        guard MockAuthStore.shared.loginClient(login: login, password: password) else {
            errorMessage = "Неверный логин или пароль"
            passwordContentType = .oneTimeCode
            return
        }
        errorMessage = nil
        passwordContentType = .password
        route = .home
    }

    private func goToRegister() {
        password = ""
        errorMessage = nil
        passwordContentType = .password
        route = .register
    }
}

#Preview {
    NavigationStack {
        ClientLoginView()
    }
}
