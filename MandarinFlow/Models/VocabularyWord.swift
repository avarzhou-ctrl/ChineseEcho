//
//  VocabularyWord.swift
//  MandarinFlow
//
//  Created by Ava Zhou on 2026/7/11.
//

import Foundation
import SwiftData

// Persists one vocabulary entry, its review state, enrichment, tags, and owning set.
@Model
nonisolated final class VocabularyWord {
    // Provides a context-independent identity for background fetches and updates.
    var recordID: UUID = UUID()
    var chinese: String
    var englishTranslation: String
    var pinyin: String
    var learnerHint: String?
    
    // Tracks review state and idiom-specific generation paths.
    var isMissedWord: Bool
    var isIdiom: Bool

    // Optional fields let existing stores migrate without scheduling untouched words.
    var reviewBox: Int?
    var lastReviewedAt: Date?
    var nextReviewAt: Date?
    
    // Optional because LLM enrichment happens after the word is saved.
    var generatedSentence: String?
    var generatedBreakdown: String?
    var tags: [String]
    
    // Inverse link back to the owning dictation session.
    var session: DictationSet?
    
    init(
        recordID: UUID = UUID(),
        chinese: String,
        englishTranslation: String,
        pinyin: String,
        learnerHint: String? = nil,
        isMissedWord: Bool = false,
        isIdiom: Bool = false,
        reviewBox: Int? = nil,
        lastReviewedAt: Date? = nil,
        nextReviewAt: Date? = nil,
        tags: [String] = []
    ) {
        self.recordID = recordID
        self.chinese = chinese
        self.englishTranslation = englishTranslation
        self.pinyin = pinyin
        self.learnerHint = learnerHint
        self.isMissedWord = isMissedWord
        self.isIdiom = isIdiom
        self.reviewBox = reviewBox
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewAt = nextReviewAt
        self.tags = tags
    }
}

extension VocabularyWord {
    nonisolated var reviewScheduleSnapshot: ReviewScheduleSnapshot {
        ReviewScheduleSnapshot(
            reviewBox: reviewBox,
            lastReviewedAt: lastReviewedAt,
            nextReviewAt: nextReviewAt
        )
    }
}
