import Foundation
import UserNotifications

/// Schedules daily local notifications reminding the user to take each
/// supplement at its configured time.
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let prefix = "supplement."
    private let mealPrefix = "meal."

    /// Current authorization status.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { cont in
            center.getNotificationSettings { cont.resume(returning: $0.authorizationStatus) }
        }
    }

    /// Ask for permission if we have never asked before. Returns whether granted.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Ask only when still undetermined (used when adding a supplement after onboarding).
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await authorizationStatus()
        switch status {
        case .notDetermined: return await requestAuthorization()
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    /// Rebuild all supplement notifications from the current list.
    func reschedule(for supplements: [Supplement]) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(self.prefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)

            for supplement in supplements {
                guard let hm = supplement.hourMinute else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Supplement reminder"
                content.body = "Time to take \(supplement.name)."
                content.sound = .default

                var components = DateComponents()
                components.hour = hm.hour
                components.minute = hm.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

                let request = UNNotificationRequest(
                    identifier: self.prefix + supplement.id.uuidString,
                    content: content,
                    trigger: trigger
                )
                self.center.add(request)
            }
        }
    }

    /// Rebuild daily meal reminders from settings.
    func scheduleMealReminders(_ reminders: MealReminders) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(self.mealPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)

            for (meal, time) in reminders.activeTimes {
                let parts = time.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2 else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Log your \(meal.rawValue)"
                content.body = "Don't forget to log what you ate for \(meal.rawValue)."
                content.sound = .default

                var components = DateComponents()
                components.hour = parts[0]
                components.minute = parts[1]
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: self.mealPrefix + meal.rawValue,
                    content: content, trigger: trigger)
                self.center.add(request)
            }
        }
    }
}
