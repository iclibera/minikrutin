import SwiftUI
import SwiftData

struct SettingsView: View {
    let baby: Baby
    @EnvironmentObject var env: AppEnvironment
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var subscriptions: SubscriptionStore
    @EnvironmentObject var sync: CloudSyncService
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Query private var entries: [LogEntry]

    @State private var showAuth = false
    @State private var showPaywall = false
    @State private var showAddBaby = false
    @State private var confirmDeleteAll = false
    @State private var working = false

    init(baby: Baby) {
        self.baby = baby
        let id = baby.id
        _entries = Query(filter: #Predicate<LogEntry> { $0.babyID == id && !$0.deleted }, sort: \.date, order: .reverse)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            accountSection
            premiumSection
            babiesSection
            featuresSection
            dataSection
            legalSection
            aboutSection
            dangerSection
        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAuth) { AuthView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showAddBaby) { NavigationStack { AddBabyView(isOnboarding: false) } }
        .alert("Tüm verileri sil", isPresented: $confirmDeleteAll) {
            Button("Vazgeç", role: .cancel) {}
            Button("Sil", role: .destructive) { Task { working = true; await env.deleteEverything(); working = false } }
        } message: {
            Text("Hesabınız (varsa) ve tüm bebek kayıtları kalıcı olarak silinir. Bu işlem geri alınamaz.")
        }
    }

    // MARK: Sections

    private var accountSection: some View {
        Section("Hesap") {
            if auth.isSignedIn {
                LabeledContent("E-posta", value: auth.user?.email ?? "")
                if sync.isSyncing {
                    HStack { Text("Eşitleniyor…"); Spacer(); ProgressView() }
                } else {
                    Button { env.triggerSync() } label: { Label("Şimdi eşitle", systemImage: "arrow.triangle.2.circlepath") }
                    if let last = sync.lastSync {
                        Text("Son eşitleme: \(Fmt.time(last))").font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                }
                Button(role: .destructive) { auth.signOut() } label: { Text("Çıkış yap") }
            } else {
                Button { showAuth = true } label: {
                    Label("Bulut yedekleme & senkronizasyon", systemImage: "icloud.and.arrow.up")
                }
                Text("İsteğe bağlı. Uygulama hesapsız da tam çalışır; veriler cihazınızda tutulur.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private var premiumSection: some View {
        Section("Premium") {
            if subscriptions.isSubscribed {
                Label("Premium aktif", systemImage: "checkmark.seal.fill").foregroundStyle(Theme.brandDark)
            } else {
                Button { showPaywall = true } label: { Label("Premium'a geç", systemImage: "crown.fill") }
            }
            Button { Task { await subscriptions.restore() } } label: { Text("Satın alımları geri yükle") }
        }
    }

    private var babiesSection: some View {
        Section("Bebek profilleri") {
            ForEach(babies) { b in
                Button {
                    env.selectedBabyID = b.id
                } label: {
                    HStack {
                        BabyAvatar(baby: b, size: 30)
                        Text(b.name).foregroundStyle(Theme.ink)
                        Spacer()
                        if b.id == baby.id { Image(systemName: "checkmark").foregroundStyle(Theme.brand) }
                    }
                }
            }
            Button {
                if !subscriptions.isSubscribed && babies.count >= 1 { showPaywall = true } else { showAddBaby = true }
            } label: {
                Label("Bebek ekle", systemImage: "plus")
            }
            if !subscriptions.isSubscribed && babies.count >= 1 {
                Text("Birden fazla bebek profili Premium özelliğidir.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private var featuresSection: some View {
        Section("Özellikler") {
            NavigationLink { RemindersView(baby: baby) } label: { Label("Hatırlatmalar", systemImage: "bell.fill") }
            NavigationLink { FamilySharingView(baby: baby) } label: { Label("Aile paylaşımı", systemImage: "person.2.fill") }
            NavigationLink { GrowthHubView(baby: baby) } label: { Label("Gelişim & sağlık", systemImage: "heart.text.square.fill") }
        }
    }

    private var dataSection: some View {
        Section("Veriler") {
            if let url = DataExport.export(baby: baby, entries: entries) {
                ShareLink(item: url) { Label("Verileri dışa aktar (JSON)", systemImage: "square.and.arrow.up") }
            }
        }
    }

    private var legalSection: some View {
        Section("Gizlilik & güven") {
            Text("MinikRutin tıbbi teşhis veya tedavi önerisi vermez. Aşı, ilaç ve sağlık kararları için doktorunuza danışın.")
                .font(.caption).foregroundStyle(Theme.inkSecondary)
            Link(destination: Links.privacy) { Label("Gizlilik Politikası", systemImage: "hand.raised.fill") }
            Link(destination: Links.terms) { Label("Terms of Use (EULA)", systemImage: "doc.text.fill") }
            Link(destination: Links.support) { Label("Destek", systemImage: "questionmark.circle.fill") }
        }
    }

    private var aboutSection: some View {
        Section("Hakkında") {
            LabeledContent("Sürüm", value: appVersion)
            Text("Sade, reklamsız ve veri mahremiyetine duyarlı bebek günlüğü.")
                .font(.caption).foregroundStyle(Theme.inkSecondary)
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) { confirmDeleteAll = true } label: {
                if working { ProgressView() } else { Text("Tüm verileri sil") }
            }
        } footer: {
            Text("Hesabınızı ve tüm kayıtları kalıcı olarak siler.")
        }
    }
}
