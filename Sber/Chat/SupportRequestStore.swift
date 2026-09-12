import Foundation

struct SupportRequest {
    let message: String
    let date: Date
}

final class SupportRequestStore {
    static let shared = SupportRequestStore()

    private(set) var requests: [SupportRequest] = []

    private init() {}

    func addRequest(message: String) {
        requests.append(SupportRequest(message: message, date: Date()))
    }
}
