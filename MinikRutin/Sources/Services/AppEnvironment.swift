import Foundation
import SwiftData
import SwiftUI

/// App-wide coordinator: owns the selected baby, premium gating helpers, and
/// CRUD operations that keep SwiftData and the cloud in sync.
@MainActor
final class AppEnvironment: ObservableObject {
    let modelContext: ModelContext
    let auth: AuthService
    let subscriptions: SubscriptionStore
    let sync: CloudSyncService
    let notifications: NotificationService

    @Published var selectedBabyID: String? {
        didSet { UserDefaults.standard.set(selectedBabyID, forKey: "selectedBabyID") }
    }

    init(modelContext: ModelContext,
         auth: AuthService,
         subscriptions: SubscriptionStore,
         sync: CloudSyncService,
         notifications: NotificationService) {
        self.modelContext = modelContext
        self.auth = auth
        self.subscriptions = subscriptions
        self.sync = sync
        self.notifications = notifications
        self.selectedBabyID = UserDefaults.standard.string(forKey: "selectedBabyID")
    }

    var isPremium: Bool { subscriptions.isSubscribed }

    // MARK: Baby selection

    func resolveSelection(_ babies: [Baby]) {
        if let id = selectedBabyID, babies.contains(where: { $0.id == id }) { return }
        selectedBabyID = babies.first?.id
    }

    func baby(in babies: [Baby]) -> Baby? {
        babies.first { $0.id == selectedBabyID } ?? babies.first
    }

    @discardableResult
    func addBaby(name: String, birthDate: Date, gender: BabyGender, photoFileName: String? = nil) -> Baby {
        let baby = Baby(name: name, birthDate: birthDate, gender: gender,
                        photoFileName: photoFileName,
                        ownerUID: auth.uid,
                        memberUIDs: auth.uid.map { [$0] } ?? [])
        modelContext.insert(baby)
        save()
        selectedBabyID = baby.id
        triggerSync()
        return baby
    }

    func updateBaby(_ baby: Baby) {
        baby.updatedAt = Date()
        save()
        triggerSync()
    }

    func deleteBaby(_ baby: Baby, allEntries: [LogEntry]) {
        ImageStore.delete(baby.photoFileName)
        for e in allEntries where e.babyID == baby.id { modelContext.delete(e) }
        modelContext.delete(baby)
        save()
        if selectedBabyID == baby.id { selectedBabyID = nil }
    }

    // MARK: Entry CRUD

    func add(_ entry: LogEntry) {
        modelContext.insert(entry)
        save()
        triggerSync()
    }

    func touch(_ entry: LogEntry) {
        entry.updatedAt = Date()
        save()
        triggerSync()
    }

    func delete(_ entry: LogEntry) {
        if auth.isSignedIn {
            entry.deleted = true
            entry.updatedAt = Date()
            save()
            triggerSync()
        } else {
            modelContext.delete(entry)
            save()
        }
    }

    func save() {
        do { try modelContext.save() } catch { /* SwiftData autosave fallback */ }
    }

    func triggerSync() {
        guard auth.isSignedIn else { return }
        Task { await sync.syncNow(context: modelContext) }
    }

    // MARK: Account lifecycle

    /// Deletes the cloud account and ALL associated data (App Store 5.1.1(v)).
    func deleteAccountAndCloudData() async {
        await sync.deleteAllCloudData(context: modelContext)
        try? await auth.deleteAccount()
    }

    /// Wipes everything: cloud account + cloud data (if signed in) and all
    /// on-device data. Returns the app to onboarding.
    func deleteEverything() async {
        await deleteAccountAndCloudData()
        for m in (try? modelContext.fetch(FetchDescriptor<Memory>())) ?? [] {
            ImageStore.delete(m.photoFileName); modelContext.delete(m)
        }
        for e in (try? modelContext.fetch(FetchDescriptor<LogEntry>())) ?? [] { modelContext.delete(e) }
        for r in (try? modelContext.fetch(FetchDescriptor<ReminderItem>())) ?? [] {
            notifications.cancel(r.id); modelContext.delete(r)
        }
        for b in (try? modelContext.fetch(FetchDescriptor<Baby>())) ?? [] {
            ImageStore.delete(b.photoFileName); modelContext.delete(b)
        }
        selectedBabyID = nil
        save()
    }
}
