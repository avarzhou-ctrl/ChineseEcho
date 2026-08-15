import Foundation

// Centralizes UserDefaults keys so settings views and playback services stay synchronized.
enum AppPreferenceKey {
    static let voiceIdentifier = "speechVoiceIdentifier"
    static let pronunciationProfile = "pronunciationProfile"
    static let speechRate = "speechRate"
    static let speechPitch = "speechPitch"
    static let interWordPause = "interWordPause"
    static let repeatCount = "practiceRepeatCount"
    static let keepCardsRevealed = "practiceKeepCardsRevealed"
    static let practiceAnalytics = "practiceAnalytics"

    static let all = [
        voiceIdentifier,
        pronunciationProfile,
        speechRate,
        speechPitch,
        interWordPause,
        repeatCount,
        keepCardsRevealed
    ]
}

// Provides the persisted learning metrics shown on the Smart Dictation dashboard.
nonisolated struct PracticeAnalyticsSnapshot: Equatable, Sendable {
    let correctAttempts: Int
    let totalAttempts: Int
    let studyStreak: Int
    let masteredVocabulary: Set<String>

    static let empty = PracticeAnalyticsSnapshot(
        correctAttempts: 0,
        totalAttempts: 0,
        studyStreak: 0,
        masteredVocabulary: []
    )

    var accuracy: Double? {
        guard totalAttempts > 0 else { return nil }
        return Double(correctAttempts) / Double(totalAttempts)
    }
}

extension Notification.Name {
    static let practiceAnalyticsDidChange = Notification.Name("practiceAnalyticsDidChange")
}

// Stores compact daily totals and current word mastery without expanding the SwiftData schema.
@MainActor
enum PracticeAnalyticsStore {
    private struct DayRecord: Codable {
        var correctAttempts: Int
        var totalAttempts: Int
    }

    private struct StoredAnalytics: Codable {
        var days: [String: DayRecord] = [:]
        var mastery: [String: Bool] = [:]
    }

    static func snapshot() -> PracticeAnalyticsSnapshot {
        let analytics = load()
        return PracticeAnalyticsSnapshot(
            correctAttempts: analytics.days.values.reduce(0) { $0 + $1.correctAttempts },
            totalAttempts: analytics.days.values.reduce(0) { $0 + $1.totalAttempts },
            studyStreak: streak(from: analytics.days),
            masteredVocabulary: Set(
                analytics.mastery.compactMap { key, isMastered in isMastered ? key : nil }
            )
        )
    }

    static func masteryState(for vocabularyKey: String) -> Bool? {
        load().mastery[vocabularyKey]
    }

    static func recordResult(isCorrect: Bool, vocabularyKey: String) {
        var analytics = load()
        let key = dayKey(for: Date())
        var day = analytics.days[key] ?? DayRecord(correctAttempts: 0, totalAttempts: 0)
        day.totalAttempts += 1
        if isCorrect { day.correctAttempts += 1 }
        analytics.days[key] = day
        analytics.mastery[vocabularyKey] = isCorrect
        save(analytics)
    }

    static func undoResult(
        isCorrect: Bool,
        vocabularyKey: String,
        restoringMastery previousMastery: Bool?
    ) {
        var analytics = load()
        let key = dayKey(for: Date())
        if var day = analytics.days[key] {
            day.totalAttempts = max(day.totalAttempts - 1, 0)
            if isCorrect { day.correctAttempts = max(day.correctAttempts - 1, 0) }
            if day.totalAttempts == 0 {
                analytics.days.removeValue(forKey: key)
            } else {
                analytics.days[key] = day
            }
        }
        analytics.mastery[vocabularyKey] = previousMastery
        save(analytics)
    }

    private static func load() -> StoredAnalytics {
        guard let data = UserDefaults.standard.data(forKey: AppPreferenceKey.practiceAnalytics),
              let analytics = try? JSONDecoder().decode(StoredAnalytics.self, from: data)
        else { return StoredAnalytics() }
        return analytics
    }

    private static func save(_ analytics: StoredAnalytics) {
        guard let data = try? JSONEncoder().encode(analytics) else { return }
        UserDefaults.standard.set(data, forKey: AppPreferenceKey.practiceAnalytics)
        NotificationCenter.default.post(name: .practiceAnalyticsDidChange, object: nil)
    }

    private static func streak(from days: [String: DayRecord]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startsToday = days[dayKey(for: today)] != nil
        let anchor = startsToday
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var count = 0
        var date = anchor

        while days[dayKey(for: date)] != nil {
            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previousDay
        }
        return count
    }

    private static func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

// Defines the first-launch values used by speech and practice controls.
enum AppPreferenceDefault {
    static let pronunciationProfile = "Mainland Mandarin"
    static let speechRate = 0.5
    static let speechPitch = 1.0
    static let interWordPause = 1.25
    static let repeatCount = 1
    static let keepCardsRevealed = false
}

// Provides one reset operation for every MandarinFlow-specific preference.
extension UserDefaults {
    func resetTingXiePreferences() {
        AppPreferenceKey.all.forEach(removeObject(forKey:))
    }
}
