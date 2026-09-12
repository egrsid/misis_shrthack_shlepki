//
//  AuthTheme.swift
//  Sber
//

import SwiftUI

extension Color {
    static let pantone349 = Color(red: 0 / 255, green: 83 / 255, blue: 58 / 255)

    static let authGradientTop = Color(red: 61 / 255, green: 220 / 255, blue: 151 / 255)
    static let authGradientMiddle = Color(red: 29 / 255, green: 184 / 255, blue: 113 / 255)
    static let authGradientBottom = Color(red: 6 / 255, green: 107 / 255, blue: 74 / 255)
}

struct AuthBackground<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.authGradientTop, .authGradientMiddle, .authGradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                content
            }
            .padding(.horizontal, 32)
        }
    }
}

struct AuthField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct AuthPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.pantone349)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
        }
    }
}
