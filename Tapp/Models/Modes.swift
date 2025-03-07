//
//  Modes.swift
//  Tapp
//
//  Created by Kamil Łobiński on 07/03/2025.
//

enum Modes: String, CaseIterable {
    case Default
    
    var folderName: String {
        return self.rawValue
    }
}
