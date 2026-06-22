import Foundation

/// Reads the Firebase project configuration from GoogleService-Info.plist and
/// exposes the REST endpoints used for auth + Firestore sync. No Firebase SDK
/// is linked — we talk to the same backend over HTTPS with the project's
/// public API key and the signed-in user's ID token.
enum FirebaseConfig {
    static let apiKey: String = value("API_KEY")
    static let projectID: String = value("PROJECT_ID")

    private static func value(_ key: String) -> String {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url),
              let v = dict[key] as? String else { return "" }
        return v
    }

    static var isConfigured: Bool { !apiKey.isEmpty && !projectID.isEmpty }

    static var identityBase: String { "https://identitytoolkit.googleapis.com/v1/accounts" }
    static var secureTokenURL: String { "https://securetoken.googleapis.com/v1/token?key=\(apiKey)" }
    static var firestoreBase: String {
        "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents"
    }
}
