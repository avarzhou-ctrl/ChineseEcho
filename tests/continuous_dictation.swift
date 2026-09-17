import Foundation
import SwiftData

// Generation and string UI helpers are unrelated to these production persistence tests.
nonisolated struct ContextualSentenceGenerationTarget: Sendable {
    let wordRecordID: UUID
    let chinese: String
    let englishTranslation: String
}
extension String {
    var tingXieNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension DictationStore {
    func seed(_ ids: [UUID]) throws {
        for id in ids {
            modelContext.insert(VocabularyWord(recordID: id, chinese: "学习", englishTranslation: "study", pinyin: "xué xí"))
        }
        try modelContext.save()
    }
    func states() throws -> [UUID: ReviewScheduleSnapshot] {
        Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<VocabularyWord>()).map {
            ($0.recordID, $0.reviewScheduleSnapshot)
        })
    }
}

@main struct ContinuousDictationTests {
    @MainActor static func main() async throws {
        let container = try ModelContainer(for: VocabularyWord.self, DictationSet.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = DictationStore(modelContainer: container)
        let ids = [UUID(), UUID(), UUID()]
        try await store.seed(ids)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        func request(_ id: UUID, missed: Bool = false) -> PracticeResultRequest {
            PracticeResultRequest(wordRecordID: id, isMissed: missed,
                reviewedAt: date, scheduleConfiguration: .balanced)
        }
        do {
            try await store.applyDictationResults([request(ids[0]), request(UUID())])
            fatalError("A missing word must fail the entire submission")
        } catch {}
        let rolledBack = try await store.states()
        precondition(rolledBack.values.allSatisfy { $0.reviewBox == nil }, "Failure must roll back earlier words")
        let batch = [request(ids[0]), request(ids[1], missed: true)]
        try await store.applyDictationResults(batch)
        let first = try await store.states()
        precondition(first[ids[0]]?.lastReviewedAt == date)
        precondition(first[ids[1]]?.lastReviewedAt == date)
        precondition(first[ids[2]]?.reviewBox == nil, "Unheard words remain ungraded")
        let reloadedStore = DictationStore(modelContainer: container)
        try await reloadedStore.applyDictationResults(batch)
        let retried = try await reloadedStore.states()
        precondition(first == retried, "A retry through a new actor must not advance review dates again")

        // This executable has its own defaults domain; preserve it around analytics assertions.
        let previousAnalytics = UserDefaults.standard.data(forKey: AppPreferenceKey.practiceAnalytics)
        defer {
            if let previousAnalytics { UserDefaults.standard.set(previousAnalytics, forKey: AppPreferenceKey.practiceAnalytics) }
            else { UserDefaults.standard.removeObject(forKey: AppPreferenceKey.practiceAnalytics) }
        }
        PracticeAnalyticsStore.restore(.empty)
        let submission = UUID()
        let results = [(key: "学习", setKey: "set", correct: true), (key: "勇敢", setKey: "set", correct: false)]
        PracticeAnalyticsStore.recordDictation(id: submission, recordedAt: date, results: results)
        let snapshot = PracticeAnalyticsStore.snapshot()
        precondition(snapshot.totalAttempts == 2 && snapshot.correctAttempts == 1)
        let backup = PracticeAnalyticsStore.backup()
        PracticeAnalyticsStore.restore(backup)
        PracticeAnalyticsStore.recordDictation(id: submission, recordedAt: date, results: results)
        precondition(PracticeAnalyticsStore.snapshot() == snapshot, "Receipts must survive backup restore")

        var draft = SavedContinuousDictation()
        draft.heardWordIDs = [ids[0], ids[1]]
        draft.missedWordIDs = [ids[1]]
        draft.phase = .marking
        draft.submissionDate = date
        let saved = SavedPracticeSession(version: 3, sourceKind: .set, setRecordID: UUID(),
            filter: "All Words", queueWordRecordIDs: ids.reversed(), currentIndex: 1, grades: [],
            isQueueShuffled: true, isCardFlipped: false, savedAt: date, dictation: draft)
        let decoded = try JSONDecoder().decode(SavedPracticeSession.self, from: JSONEncoder().encode(saved))
        precondition(saved == decoded && !decoded.isComplete, "Unsubmitted marking survives relaunch in playback order")
        precondition(draft.isValid(for: ids))
        draft.missedWordIDs.insert(ids[2])
        precondition(!draft.isValid(for: ids), "Unheard answers cannot be marked")
        draft.missedWordIDs.remove(ids[2])
        draft.writingSeconds = 0
        precondition(!draft.isValid(for: ids), "Invalid timers must not be restored")
        var completed = saved
        completed.dictation?.phase = .results
        precondition(completed.isComplete, "Saved partial dictation results also clear the checkpoint")
        print("Continuous dictation persistence, atomic save, retry and analytics tests passed")
    }
}
