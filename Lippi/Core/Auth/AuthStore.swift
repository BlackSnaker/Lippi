import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var session: AuthSession?
    @Published private(set) var isRestoring = true
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    private let service: LocalAuthService
    private var didBootstrap = false

    init(service: LocalAuthService = LocalAuthService()) {
        self.service = service
    }

    var isAuthenticated: Bool { session != nil }

    func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        Task { await restoreSession() }
    }

    func restoreSession() async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            session = try await service.restoreSession()
        } catch {
            session = nil
            errorMessage = map(error)
        }
    }

    func signIn(email: String, password: String) async {
        await runTask {
            let newSession = try await self.service.signIn(email: email, password: password)
            self.session = newSession
            self.errorMessage = nil
        }
    }

    func signUp(email: String, password: String, displayName: String) async {
        await runTask {
            let newSession = try await self.service.signUp(email: email, password: password, displayName: displayName)
            self.session = newSession
            self.errorMessage = nil
        }
    }

    func signOut() {
        Task {
            do {
                try await service.signOut()
            } catch {
                errorMessage = map(error)
            }
            session = nil
        }
    }

    private func runTask(_ operation: @escaping () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            try await operation()
        } catch {
            errorMessage = map(error)
        }
    }

    private func map(_ error: Error) -> String {
        if let authError = error as? AuthError {
            return authError.localizedDescription
        }

        if let keychain = error as? KeychainStore.KeychainError {
            switch keychain {
            case .unexpectedStatus(let status):
                return "Ошибка Keychain: \(status)."
            }
        }

        return error.localizedDescription
    }
}
