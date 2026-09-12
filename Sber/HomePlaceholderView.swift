import SwiftUI

struct HomePlaceholderView: View {
    let title: String

    var body: some View {
        AuthBackground {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NavigationStack {
        HomePlaceholderView(title: "Добро пожаловать, клиент!")
    }
}
