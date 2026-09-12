//
//  OperatorLoginView.swift
//  Sber
//

import SwiftUI

struct OperatorLoginView: View {
    @State private var login: String = ""
    @State private var password: String = ""

    var body: some View {
        AuthBackground {
            Text("Войти")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 16) {
                AuthField(placeholder: "Логин", text: $login)
                AuthField(placeholder: "Пароль", text: $password, isSecure: true)
            }

            AuthPrimaryButton(title: "Войти") {
                // TODO: обработка входа оператора
            }
        }
    }
}

#Preview {
    OperatorLoginView()
}
