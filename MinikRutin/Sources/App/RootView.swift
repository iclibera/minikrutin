import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var env: AppEnvironment
    @Environment(\.modelContext) private var context
    @Query(sort: \Baby.createdAt) private var babies: [Baby]

    @State private var didSeed = false
    @State private var showForcedPaywall = false

    private var args: [String] { ProcessInfo.processInfo.arguments }

    var body: some View {
        Group {
            if babies.isEmpty {
                OnboardingFlow()
            } else {
                MainTabView()
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear(perform: bootstrap)
        .fullScreenCover(isPresented: $showForcedPaywall) {
            PaywallView()
        }
    }

    private func bootstrap() {
        // Demo seeding for screenshots / first-run preview.
        if !didSeed {
            didSeed = true
            if args.contains("-SeedDemo") && babies.isEmpty {
                DemoData.seed(into: context, env: env)
            }
        }
        env.resolveSelection(babies)
        if args.contains("-ForcePaywall") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showForcedPaywall = true }
        }
        Task {
            await env.notifications.refreshAuthorization()
            env.triggerSync()
        }
    }
}
