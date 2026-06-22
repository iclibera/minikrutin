import SwiftUI
import SwiftData

@main
struct MinikRutinApp: App {
    let container: ModelContainer
    @StateObject private var auth: AuthService
    @StateObject private var subscriptions: SubscriptionStore
    @StateObject private var notifications: NotificationService
    @StateObject private var sync: CloudSyncService
    @StateObject private var env: AppEnvironment

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Baby.self, LogEntry.self, Memory.self, ReminderItem.self)
        } catch {
            fatalError("SwiftData container error: \(error)")
        }
        self.container = container

        let auth = AuthService()
        let subscriptions = SubscriptionStore()
        let notifications = NotificationService()
        let sync = CloudSyncService(auth: auth)
        let env = AppEnvironment(modelContext: container.mainContext,
                                 auth: auth, subscriptions: subscriptions,
                                 sync: sync, notifications: notifications)
        _auth = StateObject(wrappedValue: auth)
        _subscriptions = StateObject(wrappedValue: subscriptions)
        _notifications = StateObject(wrappedValue: notifications)
        _sync = StateObject(wrappedValue: sync)
        _env = StateObject(wrappedValue: env)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(subscriptions)
                .environmentObject(notifications)
                .environmentObject(sync)
                .environmentObject(env)
                .tint(Theme.brand)
        }
        .modelContainer(container)
    }
}
