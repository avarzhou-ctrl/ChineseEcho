import Foundation

// Describes the learner-facing choices for how aggressively review dates advance.
nonisolated enum ReviewFrequencyPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case intensive
    case balanced
    case relaxed
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .intensive: "More Often"
        case .balanced: "Standard"
        case .relaxed: "Less Often"
        case .custom: "Custom"
        }
    }

    func configuration(custom: ReviewScheduleConfiguration) -> ReviewScheduleConfiguration {
        switch self {
        case .intensive: .intensive
        case .balanced: .balanced
        case .relaxed: .relaxed
        case .custom: custom.isValid ? custom : .balanced
        }
    }
}

// Keeps all five Leitner intervals together so scheduling stays deterministic and testable.
nonisolated struct ReviewScheduleConfiguration: Codable, Equatable, Sendable {
    static let maximumIntervalDays = 365
    static let intensive = Self(box1Days: 1, box2Days: 2, box3Days: 4, box4Days: 7, box5Days: 14)
    static let balanced = Self(box1Days: 1, box2Days: 3, box3Days: 7, box4Days: 14, box5Days: 30)
    static let relaxed = Self(box1Days: 2, box2Days: 5, box3Days: 14, box4Days: 30, box5Days: 60)

    var box1Days: Int
    var box2Days: Int
    var box3Days: Int
    var box4Days: Int
    var box5Days: Int

    var intervals: [Int] {
        [box1Days, box2Days, box3Days, box4Days, box5Days]
    }

    var isValid: Bool {
        intervals.allSatisfy { (1...Self.maximumIntervalDays).contains($0) }
            && zip(intervals, intervals.dropFirst()).allSatisfy(<)
    }

    var intervalSummary: String {
        intervals.map(String.init).joined(separator: ", ") + " days"
    }

    func intervalDays(for box: Int) -> Int {
        switch box {
        case 1: box1Days
        case 2: box2Days
        case 3: box3Days
        case 4: box4Days
        default: box5Days
        }
    }
}

// Defines the small, deterministic Leitner schedule used by every practice mode.
nonisolated enum ReviewScheduler {
    static let maximumBox = 5

    static func nextState(
        previousBox: Int?,
        isCorrect: Bool,
        reviewedAt: Date,
        configuration: ReviewScheduleConfiguration = .balanced,
        calendar: Calendar = .current
    ) -> ReviewScheduleSnapshot {
        let nextBox: Int
        if isCorrect {
            nextBox = previousBox.map { min(max($0, 1) + 1, maximumBox) } ?? 2
        } else {
            nextBox = 1
        }

        let reviewDay = calendar.startOfDay(for: reviewedAt)
        let nextReviewAt = calendar.date(
            byAdding: .day,
            value: configuration.intervalDays(for: nextBox),
            to: reviewDay
        ) ?? reviewedAt
        return ReviewScheduleSnapshot(
            reviewBox: nextBox,
            lastReviewedAt: reviewedAt,
            nextReviewAt: nextReviewAt
        )
    }

    static func isDue(_ nextReviewAt: Date?, now: Date = Date()) -> Bool {
        guard let nextReviewAt else { return false }
        return nextReviewAt <= now
    }
}

// Freezes scheduling fields so a grading decision can be undone after relaunch.
nonisolated struct ReviewScheduleSnapshot: Codable, Equatable, Sendable {
    let reviewBox: Int?
    let lastReviewedAt: Date?
    let nextReviewAt: Date?

    static let unscheduled = ReviewScheduleSnapshot(
        reviewBox: nil,
        lastReviewedAt: nil,
        nextReviewAt: nil
    )
}
