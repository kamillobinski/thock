//
//  ModeMetadata.swift
//  Thock
//
//  Created by Kamil Łobiński on 27/05/2025.
//

import Foundation

struct ModeMetadata: Decodable {
    let id: UUID
    let name: String
    let isNew: Bool
}
