//
//  Item.swift
//  MandarinFlow
//
//  Created by Ava Zhou on 2026/7/10.
//

import Foundation
import SwiftData

// Retains the original sample SwiftData record used by the app's shared schema.
@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
