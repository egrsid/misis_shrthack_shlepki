import SwiftUI

/// The id is the raw value, not `self`. With `var id: Self { self }` this crashed
/// on the way to registration — found on a device by the iOS side of the team.
private enum ClientLoginRoute: String, Identifiable, Hashable {
    case register
    case home

    var id: String { rawValue }
}

struct ClientLoginView: View {
    @State private var login: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var passwordContentType: UITextContentType? = .password
    @State private var route: ClientLoginRoute?
    @State private var isWorking = false

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

            AuthPrimaryButton(title: isWorking ? "Входим…" : "Войти") {
                Task { await handleLogin() }
            }
            .disabled(isWorking)

            Button {
                goToRegister()
            } label: {
                Text("Зарегистрироваться")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .underline()
            }
            .disabled(isWorking)
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

    /// Credentials are checked by the backend against the hashed password in its
    /// database; the role is sent so a client cannot slip into the operator screen.
    private func handleLogin() async {
        isWorking = true
        errorMessage = nil
        do {
            _ = try await AuthStore.shared.signIn(
                login: login,
                password: password,
                role: .client
            )
            passwordContentType = .password
            route = .home
        } catch {
            errorMessage = error.localizedDescription
            passwordContentType = .oneTimeCode
        }
        isWorking = false
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
