//
//  Item.swift
//  TingXieFlow
//
//  Created by Ava Zhou on 2026/7/10.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
