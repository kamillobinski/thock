//
//  Mode.swift
//  Thock
//
//  Created by Kamil Łobiński on 11/03/2025.
//

import Foundation

struct Mode: Decodable, Equatable {
    let id: UUID
    let name: String
    let isNew: Bool
    var path: String
    
    static func == (lhs: Mode, rhs: Mode) -> Bool {
        return lhs.id == rhs.id
    }
}
