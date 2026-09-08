import Foundation

// Minimal dependencies let this persistence regression run without SwiftData or MLX.
nonisolated struct ReviewScheduleSnapshot: Codable, Equatable, Sendable {}
enum AppPreferenceKey {
    static let activePracticeSession = "practice-session-regression-\(UUID().uuidString)"
}

@main struct CompletionRegression {
    @MainActor static func main() throws {
        defer { PracticeSessionStore.clear() }
        let words = [UUID(), UUID()]
        let setID = UUID()
        func session(_ indices: [Int], kind: SavedPracticeSourceKind? = .set,
                     filter: String = "all", version: Int = 2) -> SavedPracticeSession {
            SavedPracticeSession(
                version: version, sourceKind: kind, setRecordID: kind == .dueReview ? nil : setID,
                filter: filter, queueWordRecordIDs: words, currentIndex: 1,
                grades: indices.map { index in
                    SavedPracticeGrade(wordRecordID: words[index], queueIndex: index,
                        wasMissed: false, markedMissed: index == 0, vocabularyKey: "word",
                        recordedAt: Date(), previousMastery: nil, previousSetMastery: nil,
                        previousReviewSchedule: nil)
                }, isQueueShuffled: true, isCardFlipped: true, savedAt: Date())
        }
        for kind in [SavedPracticeSourceKind.set, .dueReview] {
            for filter in ["all", "missed", "idioms"] {
                let partial = session([0], kind: kind, filter: filter)
                PracticeSessionStore.save(partial)
                assert(PracticeSessionStore.load(sourceKind: kind, setRecordID: partial.setRecordID) == partial)
                let complete = session([0, 1], kind: kind, filter: filter)
                assert(complete.isComplete)
                PracticeSessionStore.save(complete)
                assert(PracticeSessionStore.load(sourceKind: kind, setRecordID: complete.setRecordID) == nil)
                // Closing/disappearing after completion may attempt to persist again.
                PracticeSessionStore.save(complete)
                assert(PracticeSessionStore.load() == nil)
                // Undo or a fresh follow-up queue becomes resumable again.
                PracticeSessionStore.save(partial)
                assert(PracticeSessionStore.load() == partial)
                PracticeSessionStore.clear()
            }
        }
        assert(!session([0, 0]).isComplete, "Duplicate grades cannot complete an ungraded card")
        let partial = session([0], kind: .dueReview)
        let complete = session([0, 1])
        struct Envelope: Encodable { let sessions: [String: SavedPracticeSession] }
        UserDefaults.standard.set(try JSONEncoder().encode(Envelope(sessions: [
            "set-\(setID.uuidString)": complete, "due-review": partial
        ])), forKey: AppPreferenceKey.activePracticeSession)
        assert(PracticeSessionStore.load(sourceKind: .set, setRecordID: setID) == nil)
        assert(PracticeSessionStore.load() == partial, "Keep independent unfinished queues")
        for indices in [[0], [0, 1]] {
            let legacy = session(indices, kind: nil, version: 1)
            UserDefaults.standard.set(try JSONEncoder().encode(legacy), forKey: AppPreferenceKey.activePracticeSession)
            assert(PracticeSessionStore.load() == (indices.count == 1 ? legacy : nil))
        }
        print("Practice session completion regressions passed")
    }
}
