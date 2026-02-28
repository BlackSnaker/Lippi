import Foundation

enum AuthProvider: String, Codable, Sendable {
    case password
}

struct AuthUser: Codable, Equatable, Sendable {
    let id: String
    var displayName: String
    var email: String?
    var provider: AuthProvider
}

struct AuthSession: Codable, Equatable, Sendable {
    let token: String
    let user: AuthUser
    let issuedAt: Date
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case emailAlreadyUsed
    case invalidEmail
    case weakPassword
    case storageFailure

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Неверный email или пароль."
        case .emailAlreadyUsed:
            return "Пользователь с таким email уже существует."
        case .invalidEmail:
            return "Введите корректный email."
        case .weakPassword:
            return "Пароль должен содержать минимум 8 символов."
        case .storageFailure:
            return "Ошибка безопасного хранилища. Повторите попытку."
        }
    }
}
