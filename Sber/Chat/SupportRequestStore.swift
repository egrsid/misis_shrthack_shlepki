import Combine
import Foundation

enum SupportRequestStatus: Equatable {
    case pending
    case accepted

    var title: String {
        switch self {
        case .pending: return "Не принята"
        case .accepted: return "Принята"
        }
    }
}

struct SupportRequest: Identifiable {
    let id = UUID()
    let message: String
    let date: Date
    var status: SupportRequestStatus = .pending
}

final class SupportRequestStore: ObservableObject {
    static let shared = SupportRequestStore()

    @Published private(set) var requests: [SupportRequest] = []

    private init() {}

    func addRequest(message: String) {
        requests.append(SupportRequest(message: message, date: Date()))
    }
}
