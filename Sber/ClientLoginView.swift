//
//  ClientLoginView.swift
//  Sber
//

import SwiftUI

struct ClientLoginView: View {
    @State private var login: String = ""
    @State private var password: String = ""

    var body: some View {
        AuthBackground {
            Text("Авторизоваться")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 16) {
                AuthField(placeholder: "Логин", text: $login)
                AuthField(placeholder: "Пароль", text: $password, isSecure: true)
            }

            AuthPrimaryButton(title: "Войти") {
                // TODO: обработка входа клиента
            }

            NavigationLink {
                ClientRegisterView()
            } label: {
                Text("Зарегистрироваться")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .underline()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ClientLoginView()
    }
}
