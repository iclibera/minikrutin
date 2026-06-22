import SwiftUI

struct AuthView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    enum Mode { case signIn, signUp }
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var info: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mod", selection: $mode) {
                        Text("Giriş yap").tag(Mode.signIn)
                        Text("Kayıt ol").tag(Mode.signUp)
                    }.pickerStyle(.segmented)
                }
                Section("Bulut hesabı") {
                    TextField("E-posta", text: $email)
                        .textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled()
                    SecureField("Şifre", text: $password)
                }
                if mode == .signIn {
                    Button("Şifremi unuttum") { Task { await resetPassword() } }
                        .font(.caption)
                }
                if let error { Section { Text(error).foregroundStyle(Theme.danger).font(.footnote) } }
                if let info { Section { Text(info).foregroundStyle(Theme.brandDark).font(.footnote) } }
                Section {
                    Text("Bulut hesabı; verilerinizi yedeklemek ve aile/bakıcı ile paylaşmak için isteğe bağlıdır. Uygulama hesapsız da tam çalışır.")
                        .font(.caption).foregroundStyle(Theme.inkSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(mode == .signIn ? "Giriş yap" : "Kayıt ol")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: mode == .signIn ? "Giriş yap" : "Hesap oluştur",
                              enabled: isValid && !busy) { Task { await submit() } }
                    .padding(16).background(.ultraThinMaterial)
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() } } }
        }
    }

    private var isValid: Bool {
        email.contains("@") && password.count >= 6
    }

    private func submit() async {
        busy = true; error = nil; defer { busy = false }
        do {
            if mode == .signIn { try await auth.signIn(email: email, password: password) }
            else { try await auth.signUp(email: email, password: password) }
            env.triggerSync()
            dismiss()
        } catch {
            self.error = (error as? AuthError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func resetPassword() async {
        guard email.contains("@") else { error = "Önce e-posta girin."; return }
        do { try await auth.sendPasswordReset(email: email); info = "Şifre sıfırlama e-postası gönderildi." }
        catch { self.error = (error as? AuthError)?.errorDescription ?? error.localizedDescription }
    }
}
