import Foundation

enum UserRole: String, Codable, Sendable {
    case client
    // `operator` is a Swift keyword, hence the renamed case.
    case operatorRole = "operator"

    var title: String {
        switch self {
        case .client: return "Клиент"
        case .operatorRole: return "Оператор"
        }
    }
}

/// An account stored in the backend database. Never carries a password.
struct AppUser: Identifiable, Codable, Sendable, Equatable {
    let id: Int
    let login: String
    let email: String?
    let role: UserRole
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case email
        case role
        case createdAt = "created_at"
    }
}

struct RegisterPayload: Encodable, Sendable {
    let login: String
    let email: String
    let password: String
}

struct LoginPayload: Encodable, Sendable {
    let login: String
    let password: String
    /// Sent so the backend refuses a client logging in through the operator screen.
    let role: UserRole?
}

// MARK: - Viewing history

/// One product in a client's own history.
struct ProductViewRecord: Identifiable, Codable, Sendable, Equatable {
    let id: Int
    let userId: Int
    let productId: String
    let productName: String
    let price: Int?
    /// How many times this client opened the product.
    let viewsCount: Int
    let lastViewedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case productId = "product_id"
        case productName = "product_name"
        case price
        case viewsCount = "views_count"
        case lastViewedAt = "last_viewed_at"
    }
}

struct ProductViewPayload: Encodable, Sendable {
    let productId: String
    let productName: String
    let price: Int?

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case productName = "product_name"
        case price
    }
}
