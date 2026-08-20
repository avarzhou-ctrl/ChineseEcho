//
//  DictationSet.swift
//  MandarinFlow
//
//  Created by Ava Zhou on 2026/7/11.
//

import Foundation
import SwiftData

// Persists a named practice collection and owns its vocabulary through a cascade relationship.
@Model
nonisolated final class DictationSet {
    // Keeps sets addressable across launches and portable backup files.
    var recordID: UUID = UUID()
    var title: String
    var dateCreated: Date
    var iconKindRawValue: String?
    var iconValue: String?
    var iconColorRawValue: String?
    
    // Deleting a set also removes its saved words.
    @Relationship(deleteRule: .cascade)
    var vocabularyWords: [VocabularyWord] = []
    
    init(
        recordID: UUID = UUID(),
        title: String,
        dateCreated: Date = Date(),
        appearance: DictationSetAppearance = .defaultValue
    ) {
        self.recordID = recordID
        self.title = title
        self.dateCreated = dateCreated
        iconKindRawValue = appearance.kind.rawValue
        iconValue = appearance.iconValue
        iconColorRawValue = appearance.color.rawValue
    }
}

extension DictationSet {
    // Converts optional legacy fields into a complete appearance for every rendering call.
    var appearance: DictationSetAppearance {
        get {
            DictationSetAppearance(
                kindRawValue: iconKindRawValue,
                iconValue: iconValue,
                colorRawValue: iconColorRawValue
            )
        }
        set {
            iconKindRawValue = newValue.kind.rawValue
            iconValue = newValue.iconValue
            iconColorRawValue = newValue.color.rawValue
        }
    }
}
