import Foundation

struct AuthUser: Equatable {
    var uid: String
    var email: String
    var idToken: String
    var refreshToken: String
    var expiresAt: Date
}

enum AuthError: LocalizedError {
    case notConfigured
    case server(String)
    case network

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Bulut hesabı şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin."
        case .network:
            return "İnternet bağlantısı kurulamadı."
        case .server(let code):
            switch code {
            case "EMAIL_EXISTS": return "Bu e-posta zaten kayıtlı."
            case "INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD", "EMAIL_NOT_FOUND":
                return "E-posta veya şifre hatalı."
            case "WEAK_PASSWORD : Password should be at least 6 characters":
                return "Şifre en az 6 karakter olmalı."
            case "INVALID_EMAIL": return "Geçersiz e-posta adresi."
            case "CONFIGURATION_NOT_FOUND":
                return "Bulut hesabı henüz etkinleştirilmedi. Uygulama yerel modda çalışmaya devam eder."
            default: return "Bir hata oluştu: \(code)"
            }
        }
    }
}

/// Email/password authentication against Firebase Identity Toolkit over REST.
@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var user: AuthUser?
    @Published var isBusy = false

    private let refreshKey = "refreshToken"

    var isSignedIn: Bool { user != nil }
    var uid: String? { user?.uid }

    init() {
        Task { await restoreSession() }
    }

    // MARK: Session restore

    func restoreSession() async {
        guard FirebaseConfig.isConfigured, let rt = Keychain.get(refreshKey) else { return }
        do { try await refresh(using: rt) } catch { /* stay signed out */ }
    }

    // MARK: Public actions

    func signUp(email: String, password: String) async throws {
        try await authenticate(path: "signUp", email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        try await authenticate(path: "signInWithPassword", email: email, password: password)
    }

    func signOut() {
        Keychain.remove(refreshKey)
        user = nil
    }

    func sendPasswordReset(email: String) async throws {
        let url = URL(string: "\(FirebaseConfig.identityBase):sendOobCode?key=\(FirebaseConfig.apiKey)")!
        _ = try await post(url, body: ["requestType": "PASSWORD_RESET", "email": email])
    }

    /// Deletes the Firebase auth account. Caller is responsible for clearing
    /// cloud + local data first.
    func deleteAccount() async throws {
        guard let token = try await validToken() else { throw AuthError.notConfigured }
        let url = URL(string: "\(FirebaseConfig.identityBase):delete?key=\(FirebaseConfig.apiKey)")!
        _ = try await post(url, body: ["idToken": token])
        signOut()
    }

    /// Returns a fresh ID token, refreshing if it is close to expiry.
    func validToken() async throws -> String? {
        guard var current = user else { return nil }
        if current.expiresAt.timeIntervalSinceNow < 120 {
            try await refresh(using: current.refreshToken)
            current = user ?? current
        }
        return user?.idToken
    }

    // MARK: Internals

    private func authenticate(path: String, email: String, password: String) async throws {
        guard FirebaseConfig.isConfigured else { throw AuthError.notConfigured }
        isBusy = true
        defer { isBusy = false }
        let url = URL(string: "\(FirebaseConfig.identityBase):\(path)?key=\(FirebaseConfig.apiKey)")!
        let json = try await post(url, body: [
            "email": email, "password": password, "returnSecureToken": true,
        ])
        guard let idToken = json["idToken"] as? String,
              let refreshToken = json["refreshToken"] as? String,
              let uid = json["localId"] as? String else {
            throw AuthError.server("UNKNOWN")
        }
        let expires = Double(json["expiresIn"] as? String ?? "3600") ?? 3600
        user = AuthUser(uid: uid, email: email, idToken: idToken,
                        refreshToken: refreshToken, expiresAt: Date().addingTimeInterval(expires))
        Keychain.set(refreshToken, for: refreshKey)
    }

    private func refresh(using refreshToken: String) async throws {
        let url = URL(string: FirebaseConfig.secureTokenURL)!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "grant_type=refresh_token&refresh_token=\(refreshToken)".data(using: .utf8)
        let json = try await send(req)
        guard let idToken = json["id_token"] as? String,
              let newRefresh = json["refresh_token"] as? String,
              let uid = json["user_id"] as? String else {
            throw AuthError.server("UNKNOWN")
        }
        let expires = Double(json["expires_in"] as? String ?? "3600") ?? 3600
        var email = user?.email ?? ""
        if email.isEmpty { email = (try? await lookupEmail(idToken: idToken)) ?? "" }
        user = AuthUser(uid: uid, email: email, idToken: idToken,
                        refreshToken: newRefresh, expiresAt: Date().addingTimeInterval(expires))
        Keychain.set(newRefresh, for: refreshKey)
    }

    private func lookupEmail(idToken: String) async throws -> String? {
        let url = URL(string: "\(FirebaseConfig.identityBase):lookup?key=\(FirebaseConfig.apiKey)")!
        let json = try await post(url, body: ["idToken": idToken])
        let users = json["users"] as? [[String: Any]]
        return users?.first?["email"] as? String
    }

    // MARK: Networking

    private func post(_ url: URL, body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(req)
    }

    private func send(_ req: URLRequest) async throws -> [String: Any] {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw AuthError.network
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = ((json["error"] as? [String: Any])?["message"] as? String) ?? "UNKNOWN"
            throw AuthError.server(message)
        }
        return json
    }
}
