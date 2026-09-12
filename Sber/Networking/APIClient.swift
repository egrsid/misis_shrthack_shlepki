import Foundation

/// Thin async wrapper over the FastAPI backend.
///
/// Every call routes through `MockBackend` when `API.useMock` is on, so the whole
/// app keeps working offline without a single `if` inside the views.
struct APIClient {
    static let shared = APIClient()

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = API.requestTimeout
        session = URLSession(configuration: configuration)
    }

    // MARK: JSON coders

    /// The backend sends snake_case and naive ISO timestamps ("2026-09-12T10:00:00"),
    /// which `.iso8601` rejects because it has no timezone. Hence the custom parser.
    /// No key strategy on purpose: the models declare explicit CodingKeys, so the
    /// keys inside the `slots` dictionary are left exactly as the backend sent them.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = backendDate(from: raw) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported date: \(raw)")
            )
        }
        return decoder
    }()

    static let encoder: JSONEncoder = {
        JSONEncoder()
    }()

    private static func backendDate(from raw: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        // Anything with an explicit offset.
        return ISO8601DateFormatter().date(from: raw)
    }

    // MARK: Auth

    func register(login: String, email: String, password: String) async throws -> AppUser {
        if API.useMock {
            return try await MockBackend.shared.register(
                login: login, email: email, password: password
            )
        }
        return try await send(
            path: "/auth/register",
            method: "POST",
            body: RegisterPayload(login: login, email: email, password: password)
        )
    }

    func login(login: String, password: String, role: UserRole) async throws -> AppUser {
        if API.useMock {
            return try await MockBackend.shared.login(
                login: login, password: password, role: role
            )
        }
        return try await send(
            path: "/auth/login",
            method: "POST",
            body: LoginPayload(login: login, password: password, role: role)
        )
    }

    // MARK: Viewing history

    @discardableResult
    func recordView(userId: Int, product: Product) async throws -> ProductViewRecord {
        let payload = ProductViewPayload(
            productId: product.id,
            productName: product.name,
            price: product.price
        )
        if API.useMock {
            return try await MockBackend.shared.recordView(userId: userId, payload: payload)
        }
        return try await send(path: "/users/\(userId)/views", method: "POST", body: payload)
    }

    func views(forUser userId: Int) async throws -> [ProductViewRecord] {
        if API.useMock {
            return await MockBackend.shared.views(forUser: userId)
        }
        return try await send(
            path: "/users/\(userId)/views",
            method: "GET",
            body: Optional<Never>.none
        )
    }

    func clearViews(forUser userId: Int) async throws {
        if API.useMock {
            await MockBackend.shared.clearViews(forUser: userId)
            return
        }
        try await sendWithoutResponse(path: "/users/\(userId)/views", method: "DELETE")
    }

    // MARK: Issues

    func analyze(userId: Int, text: String) async throws -> AnalyzeResponse {
        if API.useMock {
            return await MockBackend.shared.analyze(userId: userId, text: text)
        }
        return try await send(
            path: "/analyze",
            method: "POST",
            body: AnalyzeRequest(userId: userId, text: text)
        )
    }

    /// Sends the customer's answer to the fields a request is still waiting for.
    func clarify(requestId: String, text: String) async throws -> AnalyzeResponse {
        if API.useMock {
            return try await MockBackend.shared.clarify(requestId: requestId, text: text)
        }
        return try await send(
            path: "/requests/\(requestId)/clarify",
            method: "POST",
            body: ClarifyRequest(text: text)
        )
    }

    func allIssues() async throws -> [Issue] {
        if API.useMock {
            return await MockBackend.shared.allIssues()
        }
        return try await send(path: "/issues", method: "GET", body: Optional<Never>.none)
    }

    func issues(forUser userId: Int) async throws -> [Issue] {
        if API.useMock {
            return await MockBackend.shared.issues(forUser: userId)
        }
        return try await send(path: "/users/\(userId)/issues", method: "GET", body: Optional<Never>.none)
    }

    func update(issueId: Int, patch: IssuePatch) async throws -> Issue {
        if API.useMock {
            return try await MockBackend.shared.update(issueId: issueId, patch: patch)
        }
        return try await send(path: "/issues/\(issueId)", method: "PATCH", body: patch)
    }

    func generateReply(issueId: Int) async throws -> ReplyEnvelope {
        if API.useMock {
            return try await MockBackend.shared.generateReply(issueId: issueId)
        }
        return try await send(
            path: "/issues/\(issueId)/generate-reply",
            method: "POST",
            body: Optional<Never>.none
        )
    }

    func sendReply(issueId: Int, text: String) async throws -> ReplyEnvelope {
        if API.useMock {
            return try await MockBackend.shared.sendReply(issueId: issueId, text: text)
        }
        return try await send(
            path: "/issues/\(issueId)/reply",
            method: "POST",
            body: ReplyRequest(text: text)
        )
    }

    // MARK: Transport

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        guard let url = URL(string: API.base + path) else { throw APIError.badURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.offline
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw APIError.server(status: status, detail: Self.detail(from: data))
        }

        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    /// For endpoints that answer 204 with no body.
    private func sendWithoutResponse(path: String, method: String) async throws {
        guard let url = URL(string: API.base + path) else { throw APIError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = method

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.offline
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw APIError.server(status: status, detail: Self.detail(from: data))
        }
    }

    /// FastAPI reports problems as {"detail": "..."}; surface that text to the operator.
    private static func detail(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let detail = object["detail"] as? String { return detail }
        // Validation errors arrive as a list of objects, and Pydantic prefixes a
        // custom message with "Value error, " — not something to show a user.
        if let items = object["detail"] as? [[String: Any]] {
            let messages = items.compactMap { item -> String? in
                guard let message = item["msg"] as? String else { return nil }
                return message.replacingOccurrences(of: "Value error, ", with: "")
            }
            return messages.isEmpty ? nil : messages.joined(separator: ", ")
        }
        return nil
    }
}
