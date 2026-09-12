
import SwiftUI

extension Color {
    static let pantone349 = Color(red: 0 / 255, green: 83 / 255, blue: 58 / 255)

    static let authGradientTop = Color(red: 61 / 255, green: 220 / 255, blue: 151 / 255)
    static let authGradientMiddle = Color(red: 92 / 255, green: 156 / 255, blue: 163 / 255)
    static let authGradientBottom = Color(red: 40 / 255, green: 69 / 255, blue: 72 / 255)
}

struct AppGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [.authGradientTop, .authGradientMiddle, .authGradientBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct AuthBackground<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            AppGradientBackground()

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
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(textContentType)
            } else {
                TextField(placeholder, text: $text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct AuthErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.85))
            .cornerRadius(10)
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
