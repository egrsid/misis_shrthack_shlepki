import Foundation

struct ChatMessage: Identifiable {
    enum Sender {
        case user
        case assistant
    }

    let id = UUID()
    let sender: Sender
    let text: String
}
