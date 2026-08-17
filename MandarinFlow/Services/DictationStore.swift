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
    let words: [NewVocabularyWord]
}

// Keeps vocabulary edits intact while they cross from the editor to the model actor.
nonisolated struct VocabularyWordUpdateRequest: Sendable {
    let wordRecordID: UUID
    let chinese: String
    let pinyin: String
    let translation: String
    let learnerHint: String
    let isIdiom: Bool
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
        let set = DictationSet(title: request.title)
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
                wordID: $0.persistentModelID,
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
                wordID: $0.persistentModelID,
                chinese: $0.chinese,
                englishTranslation: $0.englishTranslation
            )
        }
    }

    func duplicateSet(setID: PersistentIdentifier) throws {
        guard let source = modelContext.model(for: setID) as? DictationSet else { return }
        let copyTitle = "\(source.title) Copy"
        let copy = DictationSet(title: copyTitle)
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

    func updateWord(_ request: VocabularyWordUpdateRequest) throws {
        let recordID = request.wordRecordID
        var descriptor = FetchDescriptor<VocabularyWord>(
            predicate: #Predicate { word in
                word.recordID == recordID
            }
        )
        descriptor.fetchLimit = 1
        guard let word = try modelContext.fetch(descriptor).first else {
            throw DictationStoreError.wordNotFound
        }
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

    func setGeneratedSentence(_ sentence: String, wordID: PersistentIdentifier) throws {
        guard let word = modelContext.model(for: wordID) as? VocabularyWord else { return }
        word.generatedSentence = sentence
        try modelContext.save()
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
