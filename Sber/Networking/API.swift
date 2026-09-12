import Foundation

enum API {
    /// The simulator reaches the Mac's own localhost. For a real device, replace
    /// this with the Mac's LAN address (e.g. http://192.168.1.42:8000) and make
    /// sure both are on the same Wi-Fi.
    static let base = "http://127.0.0.1:8000"

    /// Demo insurance: when the backend is unreachable during the defence, the app
    /// serves canned data instead of dying. Never silent — MockBanner is shown
    /// on screen whenever this is on.
    static var useMock = false

    static let requestTimeout: TimeInterval = 30
}

enum APIError: LocalizedError {
    case badURL
    case offline
    case server(status: Int, detail: String?)
    case decoding(String)

    // nonisolated because the project defaults new types to MainActor isolation,
    // and LocalizedError is read from actor contexts such as MockBackend.
    nonisolated var errorDescription: String? {
        switch self {
        case .badURL:
            return "Некорректный адрес сервера"
        case .offline:
            return "Сервер недоступен. Проверьте, что бэкенд запущен на \(API.base)"
        case let .server(status, detail):
            if let detail, !detail.isEmpty {
                return detail
            }
            return "Сервер вернул ошибку \(status)"
        case let .decoding(message):
            return "Не удалось разобрать ответ сервера: \(message)"
        }
    }
}
