import Foundation
import SwiftData

// Transfers editable vocabulary values across actor boundaries without carrying live SwiftData models.
nonisolated struct NewVocabularyWord: Sendable {
    let chinese: String
    let pinyin: String
    let translation: String
    let isIdiom: Bool

    init(chinese: String, pinyin: String, translation: String, isIdiom: Bool) {
        self.chinese = chinese
        self.pinyin = pinyin
        self.translation = translation
        self.isIdiom = isIdiom
    }

    init(_ word: VocabularyWord) {
        chinese = word.chinese
        pinyin = word.pinyin
        translation = word.englishTranslation
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

// Performs all set and vocabulary mutations inside a dedicated SwiftData model actor.
@ModelActor
actor DictationStore {
    func saveSet(_ request: DictationSetSaveRequest) throws {
        switch request.destination {
        case .new:
            try createSet(request)
        case .existing(let setID):
            try updateSet(setID: setID, request: request)
        }
    }

    private func createSet(_ request: DictationSetSaveRequest) throws {
        let set = DictationSet(title: request.title)
        modelContext.insert(set)

        for value in request.words {
            let word = VocabularyWord(
                chinese: value.chinese,
                englishTranslation: value.translation,
                pinyin: value.pinyin,
                isIdiom: value.isIdiom,
                tags: [request.title]
            )
            word.session = set
            set.vocabularyWords.append(word)
            modelContext.insert(word)
        }

        try modelContext.save()
    }

    private func updateSet(
        setID: PersistentIdentifier,
        request: DictationSetSaveRequest
    ) throws {
        guard let set = self[setID, as: DictationSet.self] else {
            throw DictationStoreError.setNotFound
        }
        set.title = request.title
        var unmatchedWords = set.vocabularyWords
        var updatedWords: [VocabularyWord] = []

        for value in request.words {
            let existingIndex = unmatchedWords.firstIndex {
                $0.chinese == value.chinese && $0.pinyin == value.pinyin
            }
            let word: VocabularyWord
            if let existingIndex {
                word = unmatchedWords.remove(at: existingIndex)
                word.englishTranslation = value.translation
                word.isIdiom = value.isIdiom
                word.tags = [request.title]
            } else {
                word = VocabularyWord(
                    chinese: value.chinese,
                    englishTranslation: value.translation,
                    pinyin: value.pinyin,
                    isIdiom: value.isIdiom,
                    tags: [request.title]
                )
                modelContext.insert(word)
            }
            word.session = set
            updatedWords.append(word)
        }

        for removedWord in unmatchedWords {
            modelContext.delete(removedWord)
        }
        set.vocabularyWords = updatedWords
        try modelContext.save()
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

    func updateWord(
        wordID: PersistentIdentifier,
        chinese: String,
        pinyin: String,
        translation: String,
        isIdiom: Bool
    ) throws {
        guard let word = modelContext.model(for: wordID) as? VocabularyWord else { return }
        word.chinese = chinese
        word.pinyin = pinyin
        word.englishTranslation = translation
        word.isIdiom = isIdiom
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

    var errorDescription: String? {
        "The dictation set could not be found. Close this editor and try again."
    }
}
