import Foundation
import UserNotifications

/// Schedules local reminders (vitamin D, medicine, doctor checkups). Local
/// notifications only — no remote push, no health data leaves the device.
@MainActor
final class NotificationService: ObservableObject {
    @Published var authorized = false

    func refreshAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        authorized = granted
        return granted
    }

    func sync(_ reminder: ReminderItem) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminder.id])
        guard reminder.enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "MinikRutin"
        content.body = reminder.title
        content.sound = .default

        var components = DateComponents()
        components.hour = reminder.hour
        components.minute = reminder.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: reminder.repeatsDaily)
        let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
        center.add(request)
    }

    func cancel(_ id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
