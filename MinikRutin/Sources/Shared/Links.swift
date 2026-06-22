import Foundation

/// Public URLs used across the app and required by App Store Connect.
enum Links {
    static let privacy = URL(string: "https://iclibera.github.io/minikrutin/privacy.html")!
    static let support = URL(string: "https://iclibera.github.io/minikrutin/support.html")!
    static let marketing = URL(string: "https://iclibera.github.io/minikrutin/")!
    /// Apple's standard EULA (Terms of Use).
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
