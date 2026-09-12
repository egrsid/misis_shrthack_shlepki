import Foundation

/// What the client sent and what the triage made of it.
struct SupportRequest: Identifiable {
    let id = UUID()
    let message: String
    let date: Date
    let issues: [Issue]
}

/// Client-side history of submitted requests.
///
/// The issues themselves live in the backend database; this only keeps the
/// client's own view of what they sent in this session.
@MainActor
final class SupportRequestStore: ObservableObject {
    static let shared = SupportRequestStore()

    @Published private(set) var requests: [SupportRequest] = []

    private init() {}

    func record(message: String, issues: [Issue]) {
        requests.insert(SupportRequest(message: message, date: Date(), issues: issues), at: 0)
    }
}
