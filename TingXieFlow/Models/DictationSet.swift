//
//  DictationSet.swift
//  TingXieFlow
//
//  Created by Ava Zhou on 2026/7/11.
//

import Foundation
import SwiftData

@Model
class DictationSet {
    var title: String
    var dateCreated: Date
    
    @Relationship(deleteRule: .cascade)
    var vocabularyWords: [VocabularyWord] = []
    
    init(title: String, dateCreated: Date = Date()) {
        self.title = title
        self.dateCreated = dateCreated 
    }
}
