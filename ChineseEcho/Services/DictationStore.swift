import Foundation
import SwiftData

// Transfers editable vocabulary values across actor boundaries without carrying live SwiftData models.
nonisolated struct NewVocabularyWord: Sendable {
    let chinese: String
    let pinyin: String
    let translation: String
    let learnerHint: String
    let isIdiom: Bool

    init(
        chinese: String,
        pinyin: String,
        translation: String,
        learnerHint: String = "",
        isIdiom: Bool
    ) {
        self.chinese = chinese
        self.pinyin = pinyin
        self.translation = translation
        self.learnerHint = learnerHint
        self.isIdiom = isIdiom
    }

    init(_ word: VocabularyWord) {
        chinese = word.chinese
        pinyin = word.pinyin
        translation = word.englishTranslation
        learnerHint = word.learnerHint ?? ""
        isIdiom = word.isIdiom
    }
}

// Packages every save argument into one immutable value for the model-actor hop.
nonisolated struct DictationSetSaveRequest: Sendable {
    enum Destination: Sendable {
        case new
        case existing(PersistentIdentifier)
    }

    let destination: Destination
    let title: String
    let appearance: DictationSetAppearance
    let cardLayout: VocabularyCardLayout
    let words: [NewVocabularyWord]
}

// Keeps vocabulary edits intact while they cross from the editor to the model actor.
nonisolated struct VocabularyWordUpdateRequest: Sendable {
    let wordRecordID: UUID
    let originalChinese: String
    let originalPinyin: String
    let originalTranslation: String
    let originalSetTitle: String?
    let chinese: String
    let pinyin: String
    let translation: String
    let learnerHint: String
    let isIdiom: Bool
}

// Carries one practice result into the model actor using stable vocabulary identity.
nonisolated struct PracticeResultRequest: Sendable {
    let wordRecordID: UUID
    let isMissed: Bool
    let reviewedAt: Date
    let scheduleConfiguration: ReviewScheduleConfiguration
}

// Restores both missed and scheduling state when the learner uses Undo.
nonisolated struct PracticeResultRestoreRequest: Sendable {
    let wordRecordID: UUID
    let wasMissed: Bool
    let schedule: ReviewScheduleSnapshot
}

// Returns the authoritative actor-side state needed for an exact Undo.
nonisolated struct PracticeResultPreviousState: Sendable {
    let wasMissed: Bool
    let schedule: ReviewScheduleSnapshot
}

// Performs all set and vocabulary mutations inside a dedicated SwiftData model actor.
@ModelActor
actor DictationStore {
    func saveSet(
        _ request: DictationSetSaveRequest
    ) throws -> [ContextualSentenceGenerationTarget] {
        switch request.destination {
        case .new:
            return try createSet(request)
        case .existing(let setID):
            return try updateSet(setID: setID, request: request)
        }
    }

    private func createSet(
        _ request: DictationSetSaveRequest
    ) throws -> [ContextualSentenceGenerationTarget] {
        let set = DictationSet(
            title: request.title,
            appearance: request.appearance,
            cardLayout: request.cardLayout
        )
        modelContext.insert(set)
        var newlyCreatedWords: [VocabularyWord] = []

        for value in request.words {
            let word = VocabularyWord(
                chinese: value.chinese,
                englishTranslation: value.translation,
                pinyin: value.pinyin,
                learnerHint: value.learnerHint.tingXieNilIfEmpty,
                isIdiom: value.isIdiom,
                tags: [request.title]
            )
            word.session = set
            set.vocabularyWords.append(word)
            modelContext.insert(word)
            newlyCreatedWords.append(word)
        }

        try modelContext.save()
        return newlyCreatedWords.map {
            ContextualSentenceGenerationTarget(
                wordRecordID: $0.recordID,
                chinese: $0.chinese,
                englishTranslation: $0.englishTranslation
            )
        }
    }

    private func updateSet(
        setID: PersistentIdentifier,
        request: DictationSetSaveRequest
    ) throws -> [ContextualSentenceGenerationTarget] {
        guard let set = self[setID, as: DictationSet.self] else {
            throw DictationStoreError.setNotFound
        }
        set.title = request.title
        set.appearance = request.appearance
        set.cardLayout = request.cardLayout
        var unmatchedWords = set.vocabularyWords
        var updatedWords: [VocabularyWord] = []
        var newlyCreatedWords: [VocabularyWord] = []

        for value in request.words {
            let existingIndex = unmatchedWords.firstIndex {
                $0.chinese == value.chinese && $0.pinyin == value.pinyin
            }
            let word: VocabularyWord
            if let existingIndex {
                word = unmatchedWords.remove(at: existingIndex)
                word.englishTranslation = value.translation
                word.learnerHint = value.learnerHint.tingXieNilIfEmpty
                word.isIdiom = value.isIdiom
                word.tags = [request.title]
            } else {
                word = VocabularyWord(
                    chinese: value.chinese,
                    englishTranslation: value.translation,
                    pinyin: value.pinyin,
                    learnerHint: value.learnerHint.tingXieNilIfEmpty,
                    isIdiom: value.isIdiom,
                    tags: [request.title]
                )
                modelContext.insert(word)
                newlyCreatedWords.append(word)
            }
            word.session = set
            updatedWords.append(word)
        }

        for removedWord in unmatchedWords {
            modelContext.delete(removedWord)
        }
        set.vocabularyWords = updatedWords
        try modelContext.save()
        return newlyCreatedWords.map {
            ContextualSentenceGenerationTarget(
                wordRecordID: $0.recordID,
                chinese: $0.chinese,
                englishTranslation: $0.englishTranslation
            )
        }
    }

    func duplicateSet(setID: PersistentIdentifier) throws {
        guard let source = modelContext.model(for: setID) as? DictationSet else { return }
        let copyTitle = "\(source.title) Copy"
        let copy = DictationSet(
            title: copyTitle,
            appearance: source.appearance,
            cardLayout: source.cardLayout
        )
        modelContext.insert(copy)

        for sourceWord in source.vocabularyWords {
            let word = VocabularyWord(
                chinese: sourceWord.chinese,
                englishTranslation: sourceWord.englishTranslation,
                pinyin: sourceWord.pinyin,
                learnerHint: sourceWord.learnerHint,
                isMissedWord: sourceWord.isMissedWord,
                isIdiom: sourceWord.isIdiom,
                tags: [copyTitle]
            )
            word.generatedSentence = sourceWord.generatedSentence
            word.generatedBreakdown = sourceWord.generatedBreakdown
            word.session = copy
            copy.vocabularyWords.append(word)
            modelContext.insert(word)
        }
        try modelContext.save()
    }

    func deleteSet(setID: PersistentIdentifier) throws {
        guard let set = modelContext.model(for: setID) as? DictationSet else { return }
        modelContext.delete(set)
        try modelContext.save()
    }

    func setMissed(_ isMissed: Bool, wordID: PersistentIdentifier) throws {
        guard let word = modelContext.model(for: wordID) as? VocabularyWord else { return }
        word.isMissedWord = isMissed
        try modelContext.save()
    }

    func applyPracticeResult(_ request: PracticeResultRequest) throws -> PracticeResultPreviousState {
        guard let word = try word(recordID: request.wordRecordID) else {
            throw DictationStoreError.wordNotFound
        }
        let previousState = PracticeResultPreviousState(
            wasMissed: word.isMissedWord,
            schedule: word.reviewScheduleSnapshot
        )
        let nextSchedule = ReviewScheduler.nextState(
            previousBox: word.reviewBox,
            isCorrect: !request.isMissed,
            reviewedAt: request.reviewedAt,
            configuration: request.scheduleConfiguration
        )
        word.isMissedWord = request.isMissed
        word.reviewBox = nextSchedule.reviewBox
        word.lastReviewedAt = nextSchedule.lastReviewedAt
        word.nextReviewAt = nextSchedule.nextReviewAt
        try modelContext.save()
        return previousState
    }

    // Save the entire answer sheet once; roll back every mutation if any word or save fails.
    func applyDictationResults(_ requests: [PracticeResultRequest]) throws {
        do {
            for request in requests {
                guard let word = try word(recordID: request.wordRecordID) else {
                    throw DictationStoreError.wordNotFound
                }
                // The draft keeps this timestamp through retries and relaunches.
                if let recorded = word.lastReviewedAt, recorded >= request.reviewedAt { continue }
                let next = ReviewScheduler.nextState(
                    previousBox: word.reviewBox, isCorrect: !request.isMissed,
                    reviewedAt: request.reviewedAt, configuration: request.scheduleConfiguration
                )
                word.isMissedWord = request.isMissed
                word.reviewBox = next.reviewBox
                word.lastReviewedAt = next.lastReviewedAt
                word.nextReviewAt = next.nextReviewAt
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func restorePracticeResult(_ request: PracticeResultRestoreRequest) throws {
        guard let word = try word(recordID: request.wordRecordID) else {
            throw DictationStoreError.wordNotFound
        }
        word.isMissedWord = request.wasMissed
        word.reviewBox = request.schedule.reviewBox
        word.lastReviewedAt = request.schedule.lastReviewedAt
        word.nextReviewAt = request.schedule.nextReviewAt
        try modelContext.save()
    }

    func updateWord(_ request: VocabularyWordUpdateRequest) throws {
        let word = try resolveWord(for: request)
        word.chinese = request.chinese
        word.pinyin = request.pinyin
        word.englishTranslation = request.translation
        word.learnerHint = request.learnerHint.tingXieNilIfEmpty
        word.isIdiom = request.isIdiom
        try modelContext.save()
    }

    func deleteWord(wordID: PersistentIdentifier) throws {
        guard let word = modelContext.model(for: wordID) as? VocabularyWord else { return }
        modelContext.delete(word)
        try modelContext.save()
    }

    func setGeneratedSentence(_ sentence: String, wordRecordID: UUID) throws {
        guard let word = try word(recordID: wordRecordID) else {
            throw DictationStoreError.wordNotFound
        }
        word.generatedSentence = sentence
        try modelContext.save()
    }

    private func resolveWord(
        for request: VocabularyWordUpdateRequest
    ) throws -> VocabularyWord {
        if let word = try word(recordID: request.wordRecordID) {
            return word
        }

        let originalChinese = request.originalChinese
        let originalPinyin = request.originalPinyin
        let descriptor = FetchDescriptor<VocabularyWord>(
            predicate: #Predicate { word in
                word.chinese == originalChinese && word.pinyin == originalPinyin
            }
        )
        let candidates = try modelContext.fetch(descriptor)
        let exactMatch = candidates.first { word in
            word.englishTranslation == request.originalTranslation
                && word.session?.title == request.originalSetTitle
        }
        guard let word = exactMatch ?? (candidates.count == 1 ? candidates[0] : nil) else {
            throw DictationStoreError.wordNotFound
        }

        // Persist the editor's UUID so legacy records use the direct lookup next time.
        word.recordID = request.wordRecordID
        return word
    }

    private func word(recordID: UUID) throws -> VocabularyWord? {
        var descriptor = FetchDescriptor<VocabularyWord>(
            predicate: #Predicate { word in
                word.recordID == recordID
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

// Converts missing-record failures into actionable editor messages.
private enum DictationStoreError: LocalizedError {
    case setNotFound
    case wordNotFound

    var errorDescription: String? {
        switch self {
        case .setNotFound:
            "The dictation set could not be found. Close this editor and try again."
        case .wordNotFound:
            "The vocabulary word could not be found. Close this editor and try again."
        }
    }
}
