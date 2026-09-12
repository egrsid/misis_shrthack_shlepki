import SwiftUI

struct SupportRequestsListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SupportRequestStore.shared

    fileprivate static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM, HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    var body: some View {
        ZStack {
            AppGradientBackground()

            VStack(spacing: 0) {
                header

                if store.requests.isEmpty {
                    Spacer()
                    Text("Заявок пока нет")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(store.requests.reversed()) { request in
                                SupportRequestRow(request: request)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
            }

            Spacer()

            Text("Запросы в поддержку")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

private struct SupportRequestRow: View {
    let request: SupportRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(request.message)
                .font(.system(size: 15))
                .foregroundColor(.black)
                .lineLimit(3)

            HStack {
                Text(SupportRequestsListView.dateFormatter.string(from: request.date))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                Spacer()

                Text(request.status.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(request.status == .accepted ? Color.green : Color.orange)
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
    }
}

#Preview {
    NavigationStack {
        SupportRequestsListView()
    }
}
