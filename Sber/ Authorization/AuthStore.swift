import Foundation

/// Locally caught input problems, so the user gets a readable message instead of
/// the server's validation output.
enum AuthValidationError: LocalizedError {
    case emptyLogin
    case shortLogin
    case invalidEmail
    case shortPassword

    var errorDescription: String? {
        switch self {
        case .emptyLogin: return "Введите логин"
        case .shortLogin: return "Логин должен быть не короче 3 символов"
        case .invalidEmail: return "Введите корректную почту"
        case .shortPassword: return "Пароль должен быть не короче 5 символов"
        }
    }
}

/// Who is signed in.
///
/// Credentials are checked by the backend and stored there, hashed. This holds
/// only the account returned after a successful call — no password is kept.
@MainActor
final class AuthStore: ObservableObject {
    static let shared = AuthStore()

    @Published private(set) var currentUser: AppUser?
    /// Changes on every sign-out. The root view keys its NavigationStack on this,
    /// so signing out drops the whole stack — and with it every screen and every
    /// piece of in-memory state belonging to the previous account.
    @Published private(set) var sessionId = UUID()

    private init() {}

    /// The id sent with every request tied to a person.
    ///
    /// Zero when nobody is signed in, which the backend rejects. That is on
    /// purpose: a real id here would be the seeded operator (id 1), and an
    /// unauthenticated call would quietly file a client's data on their account.
    var currentUserId: Int {
        currentUser?.id ?? 0
    }

    var isClient: Bool { currentUser?.role == .client }

    func register(login: String, email: String, password: String) async throws -> AppUser {
        let login = login.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !login.isEmpty else { throw AuthValidationError.emptyLogin }
        guard login.count >= 3 else { throw AuthValidationError.shortLogin }
        guard Self.isValidEmail(email) else { throw AuthValidationError.invalidEmail }
        guard password.count >= 5 else { throw AuthValidationError.shortPassword }

        let user = try await APIClient.shared.register(
            login: login, email: email, password: password
        )
        currentUser = user
        return user
    }

    func signIn(login: String, password: String, role: UserRole) async throws -> AppUser {
        let login = login.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !login.isEmpty else { throw AuthValidationError.emptyLogin }
        guard !password.isEmpty else { throw AuthValidationError.shortPassword }

        let user = try await APIClient.shared.login(
            login: login, password: password, role: role
        )
        currentUser = user
        return user
    }

    func signOut() {
        currentUser = nil
        sessionId = UUID()
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }
}
