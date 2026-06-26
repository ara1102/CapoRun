//
//  Item.swift
//  CapoRun
//
//  Created by Adhira on 26/06/26.
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
