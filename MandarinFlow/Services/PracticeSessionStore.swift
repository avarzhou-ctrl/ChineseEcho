import Foundation

// Captures one grading decision without depending on SwiftData object identifiers.
nonisolated struct SavedPracticeGrade: Codable, Equatable, Sendable {
    let wordRecordID: UUID
    let queueIndex: Int
    let wasMissed: Bool
    let markedMissed: Bool
    let vocabularyKey: String
    let recordedAt: Date
    let previousMastery: Bool?
    let previousSetMastery: Bool?
    let previousReviewSchedule: ReviewScheduleSnapshot?
}

nonisolated enum SavedPracticeSourceKind: String, Codable, Equatable, Sendable {
    case set
    case dueReview
}

// Persists the minimum state needed to resume the exact open practice queue.
nonisolated struct SavedPracticeSession: Codable, Equatable, Sendable {
    static let currentVersion = 2
    static let supportedVersions = 1...currentVersion

    let version: Int
    let sourceKind: SavedPracticeSourceKind?
    let setRecordID: UUID?
    let filter: String
    let queueWordRecordIDs: [UUID]
    let currentIndex: Int
    let grades: [SavedPracticeGrade]
    let isQueueShuffled: Bool
    let isCardFlipped: Bool
    let savedAt: Date

    var resolvedSourceKind: SavedPracticeSourceKind {
        sourceKind ?? .set
    }
}

extension Notification.Name {
    static let activePracticeSessionDidChange = Notification.Name("activePracticeSessionDidChange")
}

// Stores resumable sessions separately from the SwiftData library for lightweight updates.
@MainActor
enum PracticeSessionStore {
    static func load() -> SavedPracticeSession? {
        guard let data = UserDefaults.standard.data(forKey: AppPreferenceKey.activePracticeSession),
              let session = try? JSONDecoder().decode(SavedPracticeSession.self, from: data),
              SavedPracticeSession.supportedVersions.contains(session.version)
        else { return nil }
        return session
    }

    static func save(_ session: SavedPracticeSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: AppPreferenceKey.activePracticeSession)
        NotificationCenter.default.post(name: .activePracticeSessionDidChange, object: nil)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: AppPreferenceKey.activePracticeSession)
        NotificationCenter.default.post(name: .activePracticeSessionDidChange, object: nil)
    }
}
