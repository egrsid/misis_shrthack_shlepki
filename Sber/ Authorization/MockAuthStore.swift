import Foundation

struct ClientAccount {
    let login: String
    let email: String
    let password: String
}

struct OperatorAccount {
    let login: String
    let password: String
}

enum RegistrationError: LocalizedError {
    case invalidEmail
    case alreadyExists

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Введите корректную почту"
        case .alreadyExists:
            return "Такой логин или почта уже существует"
        }
    }
}

final class MockAuthStore {
    static let shared = MockAuthStore()

    private var clients: [ClientAccount] = []

    private let operators: [OperatorAccount] = [
        OperatorAccount(login: "operator", password: "12345")
    ]

    private init() {}

    func registerClient(login: String, email: String, password: String) -> RegistrationError? {
        guard Self.isValidEmail(email) else { return .invalidEmail }

        let alreadyExists = clients.contains {
            $0.login.caseInsensitiveCompare(login) == .orderedSame ||
            $0.email.caseInsensitiveCompare(email) == .orderedSame
        }
        guard !alreadyExists else { return .alreadyExists }

        clients.append(ClientAccount(login: login, email: email, password: password))
        return nil
    }

    func loginClient(login: String, password: String) -> Bool {
        clients.contains { $0.login == login && $0.password == password }
    }

    func loginOperator(login: String, password: String) -> Bool {
        operators.contains { $0.login == login && $0.password == password }
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }
}
