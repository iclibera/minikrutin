import SwiftUI

struct OnboardingFlow: View {
    var body: some View {
        NavigationStack {
            WelcomeView()
        }
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Hoş geldin")
                .font(.title2.bold())
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Theme.brandSoft)
                        .frame(width: 132, height: 132)
                    Image(systemName: "face.smiling.inverse")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.brand)
                }
                Text("MinikRutin")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.ink)
                Text("Beslenme, uyku, bez ve doktor notları tek yerde.")
                    .font(.body)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 14) {
                NavigationLink {
                    AddBabyView(isOnboarding: true)
                } label: {
                    Text("Bebeğimi ekle")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .foregroundStyle(.white)
                        .background(Theme.brand)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
                }
                Text("Sade, reklamsız ve güvenli takip")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}
