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
    private struct StoredSessions: Codable {
        var sessions: [String: SavedPracticeSession]
    }

    // Returns the most recently updated session for launch recovery and backups.
    static func load() -> SavedPracticeSession? {
        loadAll().values.max { $0.savedAt < $1.savedAt }
    }

    static func load(
        sourceKind: SavedPracticeSourceKind,
        setRecordID: UUID?
    ) -> SavedPracticeSession? {
        loadAll()[sessionKey(sourceKind: sourceKind, setRecordID: setRecordID)]
    }

    static func save(_ session: SavedPracticeSession) {
        var sessions = loadAll()
        sessions[sessionKey(
            sourceKind: session.resolvedSourceKind,
            setRecordID: session.setRecordID
        )] = session
        saveAll(sessions)
        NotificationCenter.default.post(name: .activePracticeSessionDidChange, object: nil)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: AppPreferenceKey.activePracticeSession)
        NotificationCenter.default.post(name: .activePracticeSessionDidChange, object: nil)
    }

    static func clear(
        sourceKind: SavedPracticeSourceKind,
        setRecordID: UUID?
    ) {
        var sessions = loadAll()
        sessions.removeValue(forKey: sessionKey(
            sourceKind: sourceKind,
            setRecordID: setRecordID
        ))
        saveAll(sessions)
        NotificationCenter.default.post(name: .activePracticeSessionDidChange, object: nil)
    }

    private static func loadAll() -> [String: SavedPracticeSession] {
        guard let data = UserDefaults.standard.data(forKey: AppPreferenceKey.activePracticeSession)
        else { return [:] }

        if let stored = try? JSONDecoder().decode(StoredSessions.self, from: data) {
            return stored.sessions.filter {
                SavedPracticeSession.supportedVersions.contains($0.value.version)
            }
        }

        // Migrate the original single-session payload without losing progress.
        if let legacySession = try? JSONDecoder().decode(SavedPracticeSession.self, from: data),
           SavedPracticeSession.supportedVersions.contains(legacySession.version) {
            return [sessionKey(
                sourceKind: legacySession.resolvedSourceKind,
                setRecordID: legacySession.setRecordID
            ): legacySession]
        }
        return [:]
    }

    private static func saveAll(_ sessions: [String: SavedPracticeSession]) {
        guard !sessions.isEmpty else {
            UserDefaults.standard.removeObject(forKey: AppPreferenceKey.activePracticeSession)
            return
        }
        guard let data = try? JSONEncoder().encode(StoredSessions(sessions: sessions)) else { return }
        UserDefaults.standard.set(data, forKey: AppPreferenceKey.activePracticeSession)
    }

    private static func sessionKey(
        sourceKind: SavedPracticeSourceKind,
        setRecordID: UUID?
    ) -> String {
        switch sourceKind {
        case .set:
            return "set-\(setRecordID?.uuidString ?? "missing")"
        case .dueReview:
            return "due-review"
        }
    }
}
