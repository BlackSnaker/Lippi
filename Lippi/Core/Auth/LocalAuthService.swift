import CryptoKit
import Foundation
import Security

actor LocalAuthService {
    private struct EmailAccount: Codable, Sendable {
        var userID: String
        var email: String
        var displayName: String
        var saltB64: String
        var passwordHashB64: String
        var createdAt: Date
    }

    private struct Database: Codable, Sendable {
        var emailAccounts: [EmailAccount] = []
    }

    private let keychain: KeychainStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let dbURL: URL

    private let sessionKey = "auth.session"
    private let hashIterations = 14_000

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = support.appendingPathComponent("Auth", isDirectory: true)
        self.dbURL = dir.appendingPathComponent("users.json", isDirectory: false)
    }

    func restoreSession() async throws -> AuthSession? {
        guard let data = try keychain.data(for: sessionKey) else { return nil }
        do {
            return try decoder.decode(AuthSession.self, from: data)
        } catch {
            // clean legacy session that may contain unsupported provider data
            try? clearSession()
            return nil
        }
    }

    func signIn(email: String, password: String) throws -> AuthSession {
        let normalizedEmail = normalize(email)
        guard isValid(email: normalizedEmail) else { throw AuthError.invalidEmail }

        let db = try loadDatabase()
        guard let account = db.emailAccounts.first(where: { $0.email == normalizedEmail }) else {
            throw AuthError.invalidCredentials
        }

        guard let salt = Data(base64Encoded: account.saltB64),
              let storedHash = Data(base64Encoded: account.passwordHashB64) else {
            throw AuthError.storageFailure
        }

        let candidate = hash(password: password, salt: salt)
        guard constantTimeEqual(candidate, storedHash) else {
            throw AuthError.invalidCredentials
        }

        let user = AuthUser(
            id: account.userID,
            displayName: account.displayName,
            email: account.email,
            provider: .password
        )

        let session = AuthSession(token: UUID().uuidString, user: user, issuedAt: Date())
        try persist(session: session)
        return session
    }

    func signUp(email: String, password: String, displayName: String) throws -> AuthSession {
        let normalizedEmail = normalize(email)
        guard isValid(email: normalizedEmail) else { throw AuthError.invalidEmail }
        guard password.count >= 8 else { throw AuthError.weakPassword }

        var db = try loadDatabase()
        if db.emailAccounts.contains(where: { $0.email == normalizedEmail }) {
            throw AuthError.emailAlreadyUsed
        }

        let salt = try secureRandom(count: 16)
        let hashData = hash(password: password, salt: salt)

        let account = EmailAccount(
            userID: UUID().uuidString,
            email: normalizedEmail,
            displayName: displayName.isEmpty ? fallbackName(for: normalizedEmail) : displayName,
            saltB64: salt.base64EncodedString(),
            passwordHashB64: hashData.base64EncodedString(),
            createdAt: Date()
        )

        db.emailAccounts.append(account)
        try saveDatabase(db)

        let user = AuthUser(
            id: account.userID,
            displayName: account.displayName,
            email: account.email,
            provider: .password
        )
        let session = AuthSession(token: UUID().uuidString, user: user, issuedAt: Date())
        try persist(session: session)
        return session
    }

    func signOut() throws {
        try clearSession()
    }

    private func persist(session: AuthSession) throws {
        let data = try encoder.encode(session)
        try keychain.set(data, for: sessionKey)
    }

    private func clearSession() throws {
        try keychain.remove(sessionKey)
    }

    private func ensureStorageDirectory() throws {
        let dir = dbURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func loadDatabase() throws -> Database {
        try ensureStorageDirectory()
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return Database() }
        let data = try Data(contentsOf: dbURL)
        guard !data.isEmpty else { return Database() }
        return try decoder.decode(Database.self, from: data)
    }

    private func saveDatabase(_ db: Database) throws {
        try ensureStorageDirectory()
        let data = try encoder.encode(db)
        try data.write(to: dbURL, options: .atomic)
    }

    private func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isValid(email: String) -> Bool {
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }

    private func fallbackName(for email: String) -> String {
        email.split(separator: "@").first.map(String.init) ?? "User"
    }

    private func hash(password: String, salt: Data) -> Data {
        var value = Data(password.utf8)
        value.append(salt)
        var digest = Data(SHA256.hash(data: value))

        for _ in 0..<hashIterations {
            var round = digest
            round.append(salt)
            digest = Data(SHA256.hash(data: round))
        }

        return digest
    }

    private func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<lhs.count {
            diff |= lhs[i] ^ rhs[i]
        }
        return diff == 0
    }

    private func secureRandom(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress else { return errSecAllocate }
            return SecRandomCopyBytes(kSecRandomDefault, count, base)
        }

        guard status == errSecSuccess else { throw AuthError.storageFailure }
        return data
    }

}
