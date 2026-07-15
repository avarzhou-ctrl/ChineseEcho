//
//  VocabularyWord.swift
//  TingXieFlow
//
//  Created by Ava Zhou on 2026/7/11.
//

import SwiftData

@Model
class VocabularyWord {
    var chinese: String
    var englishTranslation: String
    var pinyin: String
    
    // Tracks review state and idiom-specific generation paths.
    var isMissedWord: Bool
    var isIdiom: Bool
    
    // Optional because LLM enrichment happens after the word is saved.
    var generatedSentence: String?
    var generatedBreakdown: String?
    var tags: [String]
    
    // Inverse link back to the owning dictation session.
    var session: DictationSet?
    
    init(chinese: String, englishTranslation: String, pinyin: String, isMissedWord: Bool = false, isIdiom: Bool = false, tags: [String] = []) {
        self.chinese = chinese
        self.englishTranslation = englishTranslation
        self.pinyin = pinyin
        self.isMissedWord = isMissedWord
        self.isIdiom = isIdiom
        self.tags = tags
    }
}
