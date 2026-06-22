import SwiftUI
import SwiftData

struct MainTabView: View {
    @EnvironmentObject var env: AppEnvironment
    @Query(sort: \Baby.createdAt) private var babies: [Baby]

    @State private var tab = 0
    @State private var presentedSheet: QuickLogTarget?
    @State private var handledArgs = false

    private var activeBaby: Baby? { env.baby(in: babies) }

    var body: some View {
        Group {
            if let baby = activeBaby {
                TabView(selection: $tab) {
                    NavigationStack { TodayView(baby: baby, openLog: { presentedSheet = $0 }) }
                        .tabItem { Label("Bugün", systemImage: "house.fill") }.tag(0)

                    NavigationStack { WeeklySummaryView(baby: baby) }
                        .tabItem { Label("Özet", systemImage: "chart.bar.fill") }.tag(1)

                    NavigationStack { DoctorReportView(baby: baby) }
                        .tabItem { Label("Rapor", systemImage: "doc.text.fill") }.tag(2)

                    NavigationStack { GrowthHubView(baby: baby) }
                        .tabItem { Label("Gelişim", systemImage: "heart.text.square.fill") }.tag(3)

                    NavigationStack { SettingsView(baby: baby) }
                        .tabItem { Label("Ayarlar", systemImage: "gearshape.fill") }.tag(4)
                }
                .id(baby.id)
                .sheet(item: $presentedSheet) { target in
                    QuickLogSheet(baby: baby, target: target)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear(perform: handleLaunchArgs)
    }

    private func handleLaunchArgs() {
        guard !handledArgs else { return }
        handledArgs = true
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-screen=") }) else { return }
        let screen = String(arg.dropFirst("-screen=".count))
        switch screen {
        case "today": tab = 0
        case "summary": tab = 1
        case "report": tab = 2
        case "growth": tab = 3
        case "settings": tab = 4
        case "quicklog": tab = 0; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { presentedSheet = .menu }
        case "feeding": tab = 0; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { presentedSheet = .feeding }
        default: break
        }
    }
}
