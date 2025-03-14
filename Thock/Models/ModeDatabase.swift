//
//  ModeDatabase.swift
//  Thock
//
//  Created by Kamil Łobiński on 11/03/2025.
//

import Foundation

struct ModeDatabase {
    private var modeStorage: [Brand: [Author: [Mode]]] = [
        .Alps: [
            .tplai: [
                Mode(id: UUID(uuidString: "3cd40492-3552-48d7-af61-00411b6edb04")!, name: "SKCM Blue", path: "Resources/Sounds/Alps/tplai/SKCM_Blue/"),
            ]
        ],
        .CherryMX: [
            .mechvibes: [
                Mode(id: UUID(uuidString: "113f785e-0a0a-4300-9525-865654c619aa")!, name: "Black ABS", path: "Resources/Sounds/Cherry_MX/mechvibes/Black_ABS/"),
            ],
            .tplai: [
                Mode(id: UUID(uuidString: "8f6a8074-e5a5-49f3-b3e9-f9f735b98476")!, name: "Black", path: "Resources/Sounds/Cherry_MX/tplai/Black/"),
                Mode(id: UUID(uuidString: "191afe92-2d30-4e36-95bd-d2558879ce36")!, name: "Blue", path: "Resources/Sounds/Cherry_MX/tplai/Blue/"),
                Mode(id: UUID(uuidString: "ebd14c5d-b444-4e92-8fb7-9d6723083f94")!, name: "Brown", path: "Resources/Sounds/Cherry_MX/tplai/Brown/"),
            ]
        ],
        .Drop: [
            .tplai: [
                Mode(id: UUID(uuidString: "62a638e4-4a9e-407a-ba46-2b025b1dfbf7")!, name: "Holy Panda", path: "Resources/Sounds/Drop/tplai/Holy_Panda/"),
            ]
        ],
        .Durock: [
            .tplai: [
                Mode(id: UUID(uuidString: "60b49375-0331-4c02-8a8d-573849424828")!, name: "Alpaca", path: "Resources/Sounds/Durock/tplai/Alpaca/"),
            ]
        ],
        .Gateron: [
            .tplai: [
                Mode(id: UUID(uuidString: "de0f70c0-9123-45bf-aeea-9490fbba7200")!, name: "Ink Black", path: "Resources/Sounds/Gateron/tplai/Ink_Black/"),
                Mode(id: UUID(uuidString: "81417c50-8a5f-4243-a0bc-9a6b5c1f558e")!, name: "Ink Red", path: "Resources/Sounds/Gateron/tplai/Ink_Red/"),
                Mode(id: UUID(uuidString: "d455f490-bcad-44af-8e72-49227c38cadf")!, name: "Turquoise Tealios", path: "Resources/Sounds/Gateron/tplai/Turquoise_Tealios/"),
            ]
        ],
        .Kailh: [
            .tplai: [
                Mode(id: UUID(uuidString: "d6489ee0-c504-43d9-94fa-ff9315aa4a52")!, name: "Box Navy", path: "Resources/Sounds/Kailh/tplai/Box_Navy/"),
            ]
        ],
        .NovelKeys: [
            .tplai: [
                Mode(id: UUID(uuidString: "46276dbe-5412-415f-9709-5ba20946da46")!, name: "Cream", path: "Resources/Sounds/NovelKeys/tplai/Cream/"),
            ]
        ],
        .Topre: [
            .tplai: [
                Mode(id: UUID(uuidString: "3a7c9427-b65b-4b28-8426-e65677b6667b")!, name: "Topre", path: "Resources/Sounds/Topre/tplai/Topre/"),
            ]
        ],
        .Other: [
            .tplai: [
                Mode(id: UUID(uuidString: "1a3cc6da-e78b-4bc8-a63d-9434d891eef1")!, name: "Buckling Spring", path: "Resources/Sounds/Other/tplai/Buckling_Spring/"),
            ],
            .webdevcody: [
                Mode(id: UUID(uuidString: "10a0ce16-9f61-42c1-9b3b-17fa82293191")!, name: "Unknown", path: "Resources/Sounds/Other/webdevcody/Unknown/"),
            ]
        ]
    ]
    
    func getAllBrands() -> [Brand] {
        return Array(modeStorage.keys).sorted {
            if $0 == .Other { return false }
            if $1 == .Other { return true }
            return "\($0)" < "\($1)"
        }
    }
    
    func getAuthors(for brand: Brand) -> [Author] {
        if let authorsDict = modeStorage[brand] {
            return Array(authorsDict.keys)
        }
        return []
    }
    
    func getModes(for brand: Brand, author: Author) -> [Mode]? {
        return modeStorage[brand]?[author]
    }
    
    func findMode(by uuid: UUID) -> Mode? {
        for (_, authors) in modeStorage {
            for (_, modes) in authors {
                if let mode = modes.first(where: { $0.id == uuid }) {
                    return mode
                }
            }
        }
        return nil
    }
    
    func findBrand(for mode: Mode) -> Brand? {
        for (brand, authors) in modeStorage {
            for (_, modes) in authors {
                if modes.contains(where: { $0.id == mode.id }) {
                    return brand
                }
            }
        }
        return nil
    }
    
    func findAuthor(for mode: Mode) -> Author? {
        for (_, authors) in modeStorage {
            for (author, modes) in authors {
                if modes.contains(where: { $0.id == mode.id }) {
                    return author
                }
            }
        }
        return nil
    }
}
