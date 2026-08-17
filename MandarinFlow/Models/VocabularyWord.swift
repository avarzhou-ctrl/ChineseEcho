//
//  VocabularyWord.swift
//  MandarinFlow
//
//  Created by Ava Zhou on 2026/7/11.
//

import SwiftData

// Persists one vocabulary entry, its review state, enrichment, tags, and owning set.
@Model
nonisolated final class VocabularyWord {
    var chinese: String
    var englishTranslation: String
    var pinyin: String
    var learnerHint: String?
    
    // Tracks review state and idiom-specific generation paths.
    var isMissedWord: Bool
    var isIdiom: Bool
    
    // Optional because LLM enrichment happens after the word is saved.
    var generatedSentence: String?
    var generatedBreakdown: String?
    var tags: [String]
    
    // Inverse link back to the owning dictation session.
    var session: DictationSet?
    
    init(
        chinese: String,
        englishTranslation: String,
        pinyin: String,
        learnerHint: String? = nil,
        isMissedWord: Bool = false,
        isIdiom: Bool = false,
        tags: [String] = []
    ) {
        self.chinese = chinese
        self.englishTranslation = englishTranslation
        self.pinyin = pinyin
        self.learnerHint = learnerHint
        self.isMissedWord = isMissedWord
        self.isIdiom = isIdiom
        self.tags = tags
    }
}
