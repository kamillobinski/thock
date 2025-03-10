//
//  Modes.swift
//  Tapp
//
//  Created by Kamil Łobiński on 07/03/2025.
//

enum Modes: CaseIterable {
    case Default
    case Durock_Alpaca
    case Cherry_MX_Blue
    case Cherry_MX_Brown
    case Cherry_MX_Black
    case Gateron_Ink_Red
    case Gateron_Ink_Black
    case Gateron_Turquoise_Tealios
    case Alps_SKCM_Blue
    case Kailh_Box_Navy
    case NovelKeys_Cream
    case Buckling_Spring
    case Drop_Holy_Panda
    case Topre
    
    var displayName: String {
        switch self {
        case .Default: return "Default"
        case .Durock_Alpaca: return "Alpaca"
        case .Cherry_MX_Blue: return "Blue"
        case .Cherry_MX_Brown: return "Brown"
        case .Cherry_MX_Black: return "Black"
        case .Gateron_Ink_Red: return "Ink Red"
        case .Gateron_Ink_Black: return "Ink Black"
        case .Gateron_Turquoise_Tealios: return "Turquoise Tealios"
        case .Alps_SKCM_Blue: return "SKCM Blue"
        case .Kailh_Box_Navy: return "Box Navy"
        case .NovelKeys_Cream: return "Cream"
        case .Buckling_Spring: return "Buckling Spring"
        case .Drop_Holy_Panda: return "Holy Panda"
        case .Topre: return "Unknown"
        }
    }
    
    var folderName: String {
        switch self {
        case .Default: return "Default"
        case .Durock_Alpaca: return "Durock_Alpaca"
        case .Cherry_MX_Blue: return "Cherry_MX_Blue"
        case .Cherry_MX_Brown: return "Cherry_MX_Brown"
        case .Cherry_MX_Black: return "Cherry_MX_Black"
        case .Gateron_Ink_Red: return "Gateron_Ink_Red"
        case .Gateron_Ink_Black: return "Gateron_Ink_Black"
        case .Gateron_Turquoise_Tealios: return "Gateron_Turquoise_Tealios"
        case .Alps_SKCM_Blue: return "Alps_SKCM_Blue"
        case .Kailh_Box_Navy: return "Kailh_Box_Navy"
        case .NovelKeys_Cream: return "NovelKeys_Cream"
        case .Buckling_Spring: return "Buckling_Spring"
        case .Drop_Holy_Panda: return "Drop_Holy_Panda"
        case .Topre: return "Topre"
        }
    }
    
    var group: String {
        switch self {
        case .Default: return "Other"
        case .Durock_Alpaca: return "Durock"
        case .Gateron_Ink_Red, .Gateron_Ink_Black, .Gateron_Turquoise_Tealios: return "Gateron"
        case .Cherry_MX_Blue, .Cherry_MX_Brown, .Cherry_MX_Black: return "Cherry MX"
        case .Alps_SKCM_Blue: return "Alps"
        case .Kailh_Box_Navy: return "Kailh"
        case .NovelKeys_Cream: return "NovelKeys"
        case .Buckling_Spring: return "Vintage"
        case .Drop_Holy_Panda: return "Drop"
        case .Topre: return "Topre"
        }
    }
    
    static func fromDisplayName(_ name: String) -> Modes? {
        return Modes.allCases.first { $0.displayName == name }
    }
}
