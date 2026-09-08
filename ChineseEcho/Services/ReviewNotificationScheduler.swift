import Foundation
import UserNotifications

// Maintains one private local reminder for the learner's earliest scheduled review.
enum ReviewNotificationScheduler {
    static let requestIdentifier = "ChineseEcho.next-due-review"

    private static let scheduleModeKey = "reviewScheduleMode"
    private static let scheduledFireDateKey = "reviewNotificationScheduledFireDate"
    private static let dueScheduleMode = "dailyDueReview"
    private static let futureScheduleMode = "futureReview"
    private static let minimumLeadTime: TimeInterval = 5
    private static let reminderCooldown: TimeInterval = 86_400

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let currentStatus = await center.notificationSettings().authorizationStatus
        if isAuthorized(currentStatus) { return true }
        guard currentStatus == .notDetermined else { return false }

        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func scheduleNextReview(from reviewDates: [Date], now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard isAuthorized(status) else { return }

        let pendingRequests = await center.pendingNotificationRequests()
        // Remove reminders from earlier product names before scheduling under the new name.
        let previousIdentifiers = pendingRequests.map(\.identifier).filter {
            $0.hasSuffix(".next-due-review") && $0 != requestIdentifier
        }
        center.removePendingNotificationRequests(withIdentifiers: previousIdentifiers)
        let pendingRequest = pendingRequests.first { $0.identifier == requestIdentifier }

        guard let nextReviewAt = reviewDates.min() else {
            clearScheduledReminder(center: center)
            return
        }

        let dueCount = reviewDates.filter { $0 <= now }.count

        if dueCount > 0,
           pendingRequest?.content.userInfo[scheduleModeKey] as? String == dueScheduleMode {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = dueCount > 0 ? "Your review is ready" : "Time for a Mandarin review"
        content.body = notificationBody(dueCount: dueCount)
        content.sound = .default
        content.userInfo = ["destination": "dueReview"]

        let trigger: UNNotificationTrigger
        let scheduledFireDate: Date
        if dueCount > 0 {
            scheduledFireDate = nextDueReminderDate(now: now)
            content.userInfo[scheduleModeKey] = dueScheduleMode

            // A repeating calendar trigger delivers once at the chosen time, then no more than daily.
            let components = Calendar.current.dateComponents(
                [.hour, .minute, .second],
                from: scheduledFireDate
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        } else {
            scheduledFireDate = nextReviewAt
            content.userInfo[scheduleModeKey] = futureScheduleMode
            trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(nextReviewAt.timeIntervalSince(now), minimumLeadTime),
                repeats: false
            )
        }

        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
            UserDefaults.standard.set(scheduledFireDate, forKey: scheduledFireDateKey)
        } catch {
            UserDefaults.standard.removeObject(forKey: scheduledFireDateKey)
        }
    }

    static func cancel() {
        let center = UNUserNotificationCenter.current()
        clearScheduledReminder(center: center, removeDelivered: true)
    }

    private static func nextDueReminderDate(now: Date) -> Date {
        let earliestImmediateDate = now.addingTimeInterval(minimumLeadTime)
        guard let lastScheduledFireDate = UserDefaults.standard.object(
            forKey: scheduledFireDateKey
        ) as? Date,
              lastScheduledFireDate <= now
        else {
            return earliestImmediateDate
        }

        return max(
            lastScheduledFireDate.addingTimeInterval(reminderCooldown),
            earliestImmediateDate
        )
    }

    private static func clearScheduledReminder(
        center: UNUserNotificationCenter,
        removeDelivered: Bool = false
    ) {
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        if removeDelivered {
            center.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
        }
        UserDefaults.standard.removeObject(forKey: scheduledFireDateKey)
    }

    private static func notificationBody(dueCount: Int) -> String {
        if dueCount == 1 {
            return "One word is due. Open ChineseEcho for a quick review."
        }
        if dueCount > 1 {
            return "\(dueCount) words are due. Open ChineseEcho for a quick review."
        }
        return "Your next scheduled words are ready to practice."
    }

    private static func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }
}
