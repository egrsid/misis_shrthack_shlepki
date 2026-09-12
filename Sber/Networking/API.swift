import Foundation

enum API {
    /// The simulator reaches the Mac's own localhost, so this works as is.
    ///
    /// On a real phone, three things have to line up, and each one fails silently:
    /// 1. put the Mac's LAN address here — `ipconfig getifaddr en0` on the Mac;
    /// 2. start the backend as `uvicorn app.main:app --host 0.0.0.0`, because the
    ///    default binding is 127.0.0.1 and refuses every connection from outside;
    /// 3. phone and Mac on the same Wi-Fi, and not a guest network — venue and
    ///    university networks often isolate clients from each other, and then
    ///    nothing can fix this except a phone hotspot.
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
