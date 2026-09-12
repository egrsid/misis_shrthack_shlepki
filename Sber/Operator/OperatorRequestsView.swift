import SwiftUI

private enum RequestsSortOrder {
    case newestFirst
    case oldestFirst

    var title: String {
        switch self {
        case .newestFirst: return "Сначала новые"
        case .oldestFirst: return "Сначала старые"
        }
    }
}

struct OperatorRequestsView: View {
    @ObservedObject private var store = SupportRequestStore.shared
    @State private var sortOrder: RequestsSortOrder = .newestFirst

    private var sortedRequests: [SupportRequest] {
        switch sortOrder {
        case .newestFirst:
            return store.requests.sorted { $0.date > $1.date }
        case .oldestFirst:
            return store.requests.sorted { $0.date < $1.date }
        }
    }

    var body: some View {
        ZStack {
            AppGradientBackground()

            VStack(spacing: 0) {
                header

                if sortedRequests.isEmpty {
                    Spacer()
                    Text("Заявок пока нет")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(sortedRequests) { request in
                                OperatorRequestCard(request: request) {
                                    store.markAccepted(request)
                                }
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
            Text("Заявки")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button {
                sortOrder = sortOrder == .newestFirst ? .oldestFirst : .newestFirst
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(sortOrder.title)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

private struct OperatorRequestCard: View {
    let request: SupportRequest
    let onAccept: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM, HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(request.clientLogin)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.pantone349)

                Spacer()

                Text(Self.dateFormatter.string(from: request.date))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Text(request.message)
                .font(.system(size: 15))
                .foregroundColor(.black)

            HStack {
                Text(request.status.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(request.status == .accepted ? Color.green : Color.orange)
                    .cornerRadius(8)

                Spacer()

                if request.status == .pending {
                    Button(action: onAccept) {
                        Text("Принять")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.pantone349)
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
    }
}

#Preview {
    NavigationStack {
        OperatorRequestsView()
    }
}
