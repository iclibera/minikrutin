import SwiftUI
import AuthenticationServices

/// Google Sign-In via OAuth + PKCE using ASWebAuthenticationSession (no SDK).
/// Requires the iOS OAuth client id, which appears in GoogleService-Info.plist
/// (CLIENT_ID) once the Google provider is enabled in the Firebase console.
@MainActor
final class GoogleAuth: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static var clientID: String? {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) else { return nil }
        let id = dict["CLIENT_ID"] as? String
        return (id?.isEmpty == false) ? id : nil
    }
    static var isConfigured: Bool { clientID != nil }

    private var session: ASWebAuthenticationSession?

    func signIn(auth: AuthService, env: AppEnvironment) async throws {
        guard let clientID = Self.clientID else { throw AuthError.server("GOOGLE_NOT_CONFIGURED") }
        defer { session = nil }
        let reversed = clientID.split(separator: ".").reversed().joined(separator: ".")
        let redirectURI = "\(reversed):/oauthredirect"
        let verifier = try AuthNonce.random(length: 64)
        let challenge = AuthNonce.sha256Base64URL(verifier)

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "prompt", value: "select_account"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let s = ASWebAuthenticationSession(url: comps.url!, callbackURLScheme: reversed) { url, err in
                if let url {
                    cont.resume(returning: url)
                } else if let e = err as? ASWebAuthenticationSessionError, e.code == .canceledLogin {
                    cont.resume(throwing: CancellationError())
                } else {
                    cont.resume(throwing: err ?? AuthError.network)
                }
            }
            s.presentationContextProvider = self
            self.session = s
            if !s.start() { cont.resume(throwing: AuthError.network) }
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.server("GOOGLE_NO_CODE")
        }

        // Exchange authorization code for tokens (PKCE, no client secret).
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let unreserved = CharacterSet(charactersIn: "-._~").union(.alphanumerics)
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? s }
        let form = ["code": code, "client_id": clientID, "redirect_uri": redirectURI,
                    "grant_type": "authorization_code", "code_verifier": verifier]
        req.httpBody = form.map { "\($0)=\(enc($1))" }.joined(separator: "&").data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard let idToken = json["id_token"] as? String else { throw AuthError.server("GOOGLE_TOKEN") }
        try await auth.signInWithGoogle(idToken: idToken, accessToken: json["access_token"] as? String)
        env.triggerSync()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.first(where: { $0.activationState == .foregroundActive })?
                .windows.first(where: { $0.isKeyWindow })
            ?? scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })
            ?? scenes.flatMap { $0.windows }.first
        return window ?? ASPresentationAnchor()
    }
}

/// Google-styled sign-in button.
struct GoogleSignInButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "g.circle.fill").font(.title3)
                Text("Google ile devam et").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).frame(height: 50)
            .foregroundStyle(Theme.ink)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Color(white: 0.85)))
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        }
    }
}
