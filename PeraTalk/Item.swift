//
//  Item.swift
//  PeraTalk
//
//  Created by Taisei Abe on 2026/05/02.
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
