//
//  ClientRegisterView.swift
//  Sber
//

import SwiftUI

struct ClientRegisterView: View {
    @State private var login: String = ""
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        AuthBackground {
            Text("Регистрация")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 16) {
                AuthField(placeholder: "Логин", text: $login)
                AuthField(placeholder: "Почта", text: $email)
                AuthField(placeholder: "Пароль", text: $password, isSecure: true)
            }

            AuthPrimaryButton(title: "Зарегистрироваться") {
                // TODO: обработка регистрации клиента
            }
        }
    }
}

#Preview {
    NavigationStack {
        ClientRegisterView()
    }
}
