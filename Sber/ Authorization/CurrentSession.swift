import Foundation

final class CurrentSession {
    static let shared = CurrentSession()

    private init() {}

    var clientLogin: String = "Клиент"
}
