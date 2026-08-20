import Foundation

// Defines the small, deterministic Leitner schedule used by every practice mode.
nonisolated enum ReviewScheduler {
    static let maximumBox = 5

    static func nextState(
        previousBox: Int?,
        isCorrect: Bool,
        reviewedAt: Date,
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
            value: intervalDays(for: nextBox),
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

    private static func intervalDays(for box: Int) -> Int {
        switch box {
        case 1: 1
        case 2: 3
        case 3: 7
        case 4: 14
        default: 30
        }
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
