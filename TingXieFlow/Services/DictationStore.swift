import Foundation
import SwiftData

struct NewVocabularyWord: Sendable, Identifiable {
    let id = UUID()
    let chinese: String
    let pinyin: String
    let translation: String
    let isIdiom: Bool
}

@ModelActor
actor DictationStore {
    func createSet(title: String, words: [NewVocabularyWord]) throws {
        let set = DictationSet(title: title)
        modelContext.insert(set)

        for value in words {
            let word = VocabularyWord(
                chinese: value.chinese,
                englishTranslation: value.translation,
                pinyin: value.pinyin,
                isIdiom: value.isIdiom,
                tags: [title]
            )
            word.session = set
            set.vocabularyWords.append(word)
            modelContext.insert(word)
        }

        try modelContext.save()
    }

    func setMissed(_ isMissed: Bool, wordID: PersistentIdentifier) throws {
        guard let word = modelContext.model(for: wordID) as? VocabularyWord else { return }
        word.isMissedWord = isMissed
        try modelContext.save()
    }

    func setGeneratedSentence(_ sentence: String, wordID: PersistentIdentifier) throws {
        guard let word = modelContext.model(for: wordID) as? VocabularyWord else { return }
        word.generatedSentence = sentence
        try modelContext.save()
    }
}
