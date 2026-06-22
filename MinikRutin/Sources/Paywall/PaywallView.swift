import SwiftUI
import StoreKit

/// Guideline 3.1.2(c)-compliant paywall. Uses Apple's native
/// `SubscriptionStoreView`, exposes the policy row, and ALSO renders explicit
/// title / length / price disclosure plus prominent, clearly-labelled
/// Terms of Use (EULA) and Privacy Policy buttons on the same screen.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SubscriptionStoreView(productIDs: SubscriptionStore.productIDs) {
                marketingContent
            }
            .subscriptionStoreButtonLabel(.multiline)
            .storeButton(.visible, for: .policies)
            .storeButton(.visible, for: .restorePurchases)
            .subscriptionStorePolicyDestination(url: Links.terms, for: .termsOfService)
            .subscriptionStorePolicyDestination(url: Links.privacy, for: .privacyPolicy)
            .tint(Theme.brand)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                }
            }
        }
    }

    private var marketingContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(LinearGradient(colors: [Theme.brand, Theme.brandDark], startPoint: .top, endPoint: .bottom))
            Text("MinikRutin Premium")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("Doktor raporu, aile paylaşımı, bulut yedekleme ve gelişmiş grafikler.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                feature("Sınırsız PDF doktor raporu")
                feature("Aile / bakıcı ile ortak kullanım")
                feature("Gelişmiş grafik ve trend analizi")
                feature("Bulut yedekleme ve cihazlar arası senkronizasyon")
                feature("Birden fazla bebek profili")
            }
            .padding(.vertical, 4)

            // Explicit subscription disclosure (Guideline 3.1.2(c)).
            VStack(spacing: 4) {
                Text("MinikRutin Premium Aboneliği")
                    .font(.footnote.weight(.semibold))
                Text("Aylık: ₺99,99 / ay — 1 ay, otomatik yenilenir")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Yıllık: ₺699,99 / yıl — 12 ay, otomatik yenilenir")
                    .font(.caption).foregroundStyle(.secondary)
                Text("14 gün ücretsiz deneme. Abonelik, dönem bitmeden iptal edilmezse otomatik yenilenir. App Store ayarlarından yönetebilirsiniz.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            // Belt-and-suspenders: large, explicitly-labelled policy links.
            HStack(spacing: 18) {
                Link("Terms of Use (EULA)", destination: Links.terms)
                Link("Privacy Policy", destination: Links.privacy)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.top, 8)
    }

    private func feature(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.brand)
            Text(text).font(.subheadline)
            Spacer()
        }
    }
}
