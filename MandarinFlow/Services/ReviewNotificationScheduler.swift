import Foundation
import UserNotifications

// Maintains one private local reminder for the learner's earliest scheduled review.
enum ReviewNotificationScheduler {
    static let requestIdentifier = "mandarinflow.next-due-review"

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
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])

        let status = await center.notificationSettings().authorizationStatus
        guard isAuthorized(status), let nextReviewAt = reviewDates.min() else { return }

        let dueCount = reviewDates.filter { $0 <= now }.count
        let content = UNMutableNotificationContent()
        content.title = dueCount > 0 ? "Your review is ready" : "Time for a Mandarin review"
        content.body = notificationBody(dueCount: dueCount)
        content.sound = .default
        content.userInfo = ["destination": "dueReview"]

        // A short floor avoids an invalid interval when an overdue review is rescheduled.
        let interval = max(nextReviewAt.timeIntervalSince(now), 5)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
    }

    private static func notificationBody(dueCount: Int) -> String {
        if dueCount == 1 {
            return "One word is due. Open MandarinFlow for a quick review."
        }
        if dueCount > 1 {
            return "\(dueCount) words are due. Open MandarinFlow for a quick review."
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
