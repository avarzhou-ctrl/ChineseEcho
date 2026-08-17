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
    
    // Deleting a set also removes its saved words.
    @Relationship(deleteRule: .cascade)
    var vocabularyWords: [VocabularyWord] = []
    
    init(recordID: UUID = UUID(), title: String, dateCreated: Date = Date()) {
        self.recordID = recordID
        self.title = title
        self.dateCreated = dateCreated 
    }
}
