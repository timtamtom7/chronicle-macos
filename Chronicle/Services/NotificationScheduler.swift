import Foundation
import UserNotifications
import AppKit

// MARK: - Notification Scheduler

final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()

    /// The hour at which notifications are sent (0-23).
    /// Configurable via UserDefaults key "notificationHour", defaults to 9 (9:00 AM).
    private var notificationHour: Int {
        UserDefaults.standard.object(forKey: "notificationHour") as? Int ?? 9
    }

    private init() {}

    // MARK: - Permission

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
            DispatchQueue.main.async {
                UserDefaults.standard.set(granted, forKey: "notificationPermissionGranted")
                completion(granted)
            }
        }
    }

    var isAuthorized: Bool {
        UserDefaults.standard.bool(forKey: "notificationPermissionGranted")
    }

    var hasAskedPermission: Bool {
        UserDefaults.standard.object(forKey: "notificationPermissionGranted") != nil
    }

    // MARK: - Schedule

    func scheduleNotifications(for bill: Bill) {
        cancelNotifications(for: bill)

        guard bill.isActive, !bill.isPaid else { return }

        let timings = bill.reminderTimings.filter { $0 != .none }
        guard !timings.isEmpty else { return }

        for timing in timings {
            let fireDate = calculateFireDate(for: bill, timing: timing)
            scheduleNotification(for: bill, timing: timing, fireDate: fireDate)
        }
    }

    func cancelNotifications(for bill: Bill) {
        let identifiers = notificationIdentifiers(for: bill)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Reschedule All (on app launch)

    func rescheduleAllNotifications(bills: [Bill]) {
        cancelAllNotifications()
        for bill in bills {
            scheduleNotifications(for: bill)
        }
    }

    // MARK: - Overdue Notification

    func sendOverdueNotification(for bill: Bill) {
        let identifier = overdueIdentifier(for: bill)
        
        // Check if we already sent it today
        if let lastSent = UserDefaults.standard.object(forKey: "overdueNotificationSent_\(bill.id.uuidString)") as? Date {
            let calendar = Calendar.current
            if calendar.isDateInToday(lastSent) {
                return // Already sent today
            }
        }

        let content = UNMutableNotificationContent()
        content.title = "Chronicle"
        content.body = "\(bill.name) is overdue — was due \(formatDate(bill.dueDate))"
        content.sound = soundForNotification()
        content.categoryIdentifier = "BILL_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Failed to send overdue notification: \(error)")
            } else {
                UserDefaults.standard.set(Date(), forKey: "overdueNotificationSent_\(bill.id.uuidString)")
            }
        }
    }

    // MARK: - Snooze

    func snoozeNotification(for bill: Bill, timing: ReminderTiming) {
        let identifier = "\(bill.id.uuidString)_\(timing.rawValue)_snooze"
        let fireDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = notificationHour
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Chronicle"

        let daysText: String
        switch timing {
        case .threeDays: daysText = "in 3 days"
        case .oneDay: daysText = "tomorrow"
        case .dueDate: daysText = "today"
        case .none: daysText = ""
        }
        content.body = "\(bill.name) is due \(daysText) — \(bill.formattedAmount)"
        content.sound = soundForNotification()
        content.categoryIdentifier = "BILL_REMINDER"

        guard let triggerDate = calendar.date(from: components) else { return }
        let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Failed to snooze notification: \(error)")
            }
        }
    }

    // MARK: - Test Notification

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Chronicle"
        content.body = "Notifications are working! You will receive bill reminders at 9:00 AM."
        content.sound = soundForNotification()

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Failed to send test notification: \(error)")
            }
        }
    }

    // MARK: - Private Helpers

    private func scheduleNotification(for bill: Bill, timing: ReminderTiming, fireDate: Date) {
        let identifier = notificationIdentifier(for: bill, timing: timing)

        let content = UNMutableNotificationContent()
        content.title = "Chronicle"

        let daysText: String
        switch timing {
        case .threeDays: daysText = "in 3 days"
        case .oneDay: daysText = "tomorrow"
        case .dueDate: daysText = "today"
        case .none: daysText = ""
        }
        content.body = "\(bill.name) is due \(daysText) — \(bill.formattedAmount)"
        content.sound = soundForNotification()
        content.categoryIdentifier = "BILL_REMINDER"
        content.userInfo = ["billId": bill.id.uuidString, "timing": timing.rawValue]

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = notificationHour
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    /// Returns the notification sound based on user preference.
    /// Reads notificationSoundEnabled from UserDefaults (default: true).
    private func soundForNotification() -> UNNotificationSound? {
        let enabled = UserDefaults.standard.object(forKey: "notificationSoundEnabled") as? Bool ?? true
        return enabled ? .default : nil
    }

    private func calculateFireDate(for bill: Bill, timing: ReminderTiming) -> Date {
        let calendar = Calendar.current
        let dueDate = calendar.startOfDay(for: bill.dueDate)
        let daysOffset = timing.daysOffset
        guard let fireDate = calendar.date(byAdding: .day, value: -daysOffset, to: dueDate) else {
            return dueDate
        }
        return fireDate
    }

    private func notificationIdentifier(for bill: Bill, timing: ReminderTiming) -> String {
        "\(bill.id.uuidString)_\(timing.rawValue)"
    }

    private func overdueIdentifier(for bill: Bill) -> String {
        "\(bill.id.uuidString)_overdue"
    }

    private func notificationIdentifiers(for bill: Bill) -> [String] {
        bill.reminderTimings.map { "\(bill.id.uuidString)_\($0.rawValue)" } + [overdueIdentifier(for: bill)]
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // MARK: - Badge Count

    func updateBadgeCount(overdueCount: Int) {
        DispatchQueue.main.async {
            if #available(macOS 11.0, *) {
                NSApplication.shared.dockTile.badgeLabel = overdueCount > 0 ? "\(overdueCount)" : nil
            }
        }
    }

    func clearBadge() {
        DispatchQueue.main.async {
            if #available(macOS 11.0, *) {
                NSApplication.shared.dockTile.badgeLabel = nil
            }
        }
    }
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Check if Focus/DND is active by verifying notification settings.
        // When Focus mode or Do Not Disturb is enabled, alerts are suppressed.
        center.getNotificationSettings { settings in
            // If alerts are explicitly disabled, Focus/DND is active — suppress banner/sound
            if settings.alertSetting == .disabled {
                completionHandler([.badge])
                return
            }

            // Normal presentation when Focus is not active
            completionHandler([.banner, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let billIdString = userInfo["billId"] as? String ?? ""
        let timingRaw = userInfo["timing"] as? String ?? ""
        let billId = UUID(uuidString: billIdString)

        switch response.actionIdentifier {
        case "MARK_PAID":
            // Mark bill as paid
            if let billId = billId {
                Task { @MainActor in
                    if var bill = try? DatabaseService.shared.fetchBill(by: billId) {
                        bill = Bill(
                            id: bill.id,
                            name: bill.name,
                            amountCents: bill.amountCents,
                            dueDay: bill.dueDay,
                            dueDate: bill.dueDate,
                            recurrence: bill.recurrence,
                            category: bill.category,
                            notes: bill.notes,
                            reminderTimings: bill.reminderTimings,
                            autoMarkPaid: bill.autoMarkPaid,
                            isActive: bill.isActive,
                            isPaid: true,
                            createdAt: bill.createdAt
                        )
                        try? DatabaseService.shared.updateBill(bill)
                        NotificationScheduler.shared.cancelNotifications(for: bill)
                        NotificationCenter.default.post(name: .billsDidChange, object: nil)
                    }
                }
            }

        case "SNOOZE":
            // Snooze for 1 day
            if let billId = billId,
               let timing = ReminderTiming(rawValue: timingRaw),
               let bill = try? DatabaseService.shared.fetchBill(by: billId) {
                NotificationScheduler.shared.snoozeNotification(for: bill, timing: timing)
            }

        case UNNotificationDefaultActionIdentifier:
            // User tapped notification — open app
            NotificationCenter.default.post(name: .openAppFromNotification, object: nil)

        default:
            break
        }

        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let billsDidChange = Notification.Name("billsDidChange")
    static let openAppFromNotification = Notification.Name("openAppFromNotification")
}

// MARK: - Overdue Checker

final class OverdueChecker {
    static let shared = OverdueChecker()

    private var timer: Timer?
    private let intervalMinutes: Double = 60

    private init() {}

    func start() {
        // Initial check on start
        checkOverdue()

        // Timer every 60 minutes
        timer = Timer.scheduledTimer(withTimeInterval: intervalMinutes * 60, repeats: true) { [weak self] _ in
            self?.checkOverdue()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func checkOverdue() {
        DispatchQueue.main.async {
            let store = BillStore.shared
            let overdueBills = store.pastDue
            let count = overdueBills.count

            // Update badge
            NotificationScheduler.shared.updateBadgeCount(overdueCount: count)

            // Send overdue notifications (once per day each)
            for bill in overdueBills {
                NotificationScheduler.shared.sendOverdueNotification(for: bill)
            }
        }
    }
}
