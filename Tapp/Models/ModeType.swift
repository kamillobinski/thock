//
//  ModeType.swift
//  Tapp
//
//  Created by Kamil Łobiński on 11/03/2025.
//

enum ModeType: Hashable {
    case CherryMX(Author)
    case Other(Author)
    
    enum Author: CaseIterable {
        case tplai
    }
    
    static var allCases: [ModeType] {
        return ModeType.Author.allCases.compactMap { ModeType.CherryMX($0) }
    }
}
