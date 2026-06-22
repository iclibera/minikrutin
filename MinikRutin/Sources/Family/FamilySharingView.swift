import SwiftUI
import SwiftData

struct FamilySharingView: View {
    let baby: Baby
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject var subscriptions: SubscriptionStore
    @EnvironmentObject var sync: CloudSyncService

    @State private var inviteCode: String?
    @State private var joinCode = ""
    @State private var error: String?
    @State private var busy = false
    @State private var showAuth = false
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !auth.isSignedIn {
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Aile paylaşımı için giriş gerekli").font(.headline).foregroundStyle(Theme.ink)
                            Text("Anne, baba veya bakıcı aynı bebeği takip edebilir. Önce bulut hesabınızla giriş yapın.")
                                .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                            PrimaryButton(title: "Giriş yap / Kayıt ol") { showAuth = true }
                        }
                    }
                } else if !subscriptions.isSubscribed {
                    Button { showPaywall = true } label: {
                        Card(background: Theme.brandSoft) {
                            HStack {
                                Image(systemName: "crown.fill").foregroundStyle(Theme.brand)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Aile paylaşımı Premium ile").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                    Text("Bakıcı ve aile üyeleriyle ortak kullanım.").font(.caption).foregroundStyle(Theme.inkSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.inkSecondary)
                            }
                        }
                    }.buttonStyle(.plain)
                } else {
                    inviteCard
                    joinCard
                }

                membersCard
                if let error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Aile paylaşımı")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAuth) { AuthView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private var inviteCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Davet kodu oluştur").font(.headline).foregroundStyle(Theme.ink)
                Text("\(baby.name) için bir davet kodu oluşturun ve aile üyenizle paylaşın.")
                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                if let code = inviteCode {
                    HStack {
                        Text(code).font(.system(.title2, design: .monospaced).weight(.bold)).foregroundStyle(Theme.brandDark)
                        Spacer()
                        ShareLink(item: "MinikRutin davet kodum: \(code)") { Image(systemName: "square.and.arrow.up") }
                    }
                    .padding(12).background(Theme.brandSoft).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                SecondaryButton(title: "Kod oluştur", systemImage: "person.badge.plus") { Task { await createInvite() } }
            }
        }
    }

    private var joinCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Koda katıl").font(.headline).foregroundStyle(Theme.ink)
                TextField("6 haneli kod", text: $joinCode)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .padding(12).background(Theme.surfaceAlt).clipShape(RoundedRectangle(cornerRadius: 12))
                PrimaryButton(title: "Katıl", enabled: joinCode.count >= 6 && !busy) { Task { await join() } }
            }
        }
    }

    private var membersCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Bu bebeği takip edenler")
                Text("\(baby.memberUIDs.count) kişi")
                    .font(.subheadline).foregroundStyle(Theme.ink)
                Text("Bebek verisi hassastır; yalnızca güvendiğiniz kişilerle paylaşın.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private func createInvite() async {
        busy = true; error = nil; defer { busy = false }
        do { inviteCode = try await sync.createInvite(babyID: baby.id) }
        catch { self.error = (error as? AuthError)?.errorDescription ?? error.localizedDescription }
    }

    private func join() async {
        busy = true; error = nil; defer { busy = false }
        do { try await sync.joinWithInvite(code: joinCode, context: env.modelContext) }
        catch { self.error = (error as? AuthError)?.errorDescription ?? "Kod bulunamadı." }
    }
}
