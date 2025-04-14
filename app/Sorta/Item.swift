//
//  Item.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 14/04/2025.
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
