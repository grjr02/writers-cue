//
//  Item.swift
//  writers-cue
//
//  Created by Gregory Ross Jr on 1/16/26.
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
