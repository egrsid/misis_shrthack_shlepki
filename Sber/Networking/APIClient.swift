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

    // MARK: Endpoints

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

    /// FastAPI reports problems as {"detail": "..."}; surface that text to the operator.
    private static func detail(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let detail = object["detail"] as? String { return detail }
        // Validation errors arrive as a list of objects.
        if let items = object["detail"] as? [[String: Any]] {
            return items.compactMap { $0["msg"] as? String }.joined(separator: ", ")
        }
        return nil
    }
}
