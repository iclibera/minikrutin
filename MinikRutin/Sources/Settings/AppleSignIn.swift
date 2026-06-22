import SwiftUI
import AuthenticationServices
import CryptoKit

/// "Sign in with Apple" button that exchanges the Apple identity token with
/// Firebase via REST. Uses a SHA256-hashed nonce per Apple's requirements.
struct AppleSignInButton: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var env: AppEnvironment
    var onComplete: () -> Void = {}
    var onError: (String) -> Void = { _ in }

    @State private var currentNonce: String?

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            do {
                let nonce = try AuthNonce.random()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AuthNonce.sha256(nonce)
            } catch {
                currentNonce = nil
                onError("Güvenli giriş başlatılamadı.")
            }
        } onCompletion: { result in
            switch result {
            case .success(let authResults):
                guard let cred = authResults.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData = cred.identityToken,
                      let idToken = String(data: tokenData, encoding: .utf8),
                      let nonce = currentNonce else {
                    onError("Apple kimlik bilgisi alınamadı."); return
                }
                let name = [cred.fullName?.givenName, cred.fullName?.familyName]
                    .compactMap { $0 }.joined(separator: " ")
                Task {
                    do {
                        try await auth.signInWithApple(idToken: idToken, rawNonce: nonce, fullName: name)
                        env.triggerSync()
                        onComplete()
                    } catch {
                        onError((error as? AuthError)?.errorDescription ?? error.localizedDescription)
                    }
                }
            case .failure(let error):
                if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                    onError(error.localizedDescription)
                }
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
    }
}

/// Cryptographic nonce helpers shared by Apple Sign In and the Google PKCE flow.
enum AuthNonce {
    /// 64-char unreserved alphabet (power of two → no modulo bias). Fails
    /// closed if the system CSPRNG errors, so we never use a weak nonce/verifier.
    static func random(length: Int = 32) throws -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        guard SecRandomCopyBytes(kSecRandomDefault, length, &bytes) == errSecSuccess else {
            throw AuthError.network
        }
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_")
        return String(bytes.map { chars[Int($0) % chars.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Base64URL(_ input: String) -> String {
        Data(SHA256.hash(data: Data(input.utf8)))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
