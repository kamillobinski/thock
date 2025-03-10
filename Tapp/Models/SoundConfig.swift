//
//  SoundConfig.swift
//  Tapp
//
//  Created by Kamil Łobiński on 10/03/2025.
//

import Foundation

enum KeyType: String, Codable, CaseIterable {
    case `default` = "default"
    case space = "space"
    case enter = "enter"
    
    static func fromKeyCode(_ keyCode: Int64) -> KeyType {
        switch keyCode {
        case 36: return .enter
        case 49: return .space
        default: return .default
        }
    }
}

struct SoundConfig: Codable {
    let name: String
    let source: String
    let license: License
    let sounds: [KeyType: KeySound]
    
    // Custom Decoder to Map Dictionary Keys to KeyType Enum
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        source = try container.decode(String.self, forKey: .source)
        license = try container.decode(License.self, forKey: .license)
        let soundsDict = try container.decode([String: KeySound].self, forKey: .sounds)
        
        var mappedSounds: [KeyType: KeySound] = [:]
        for (key, value) in soundsDict {
            if let keyType = KeyType(rawValue: key) {
                mappedSounds[keyType] = value
            } else {
                print("Warning: Unknown key type '\(key)' found in JSON. Skipping.")
            }
        }
        
        sounds = mappedSounds
    }
}

struct License: Codable {
    let type: String
    let url: String
}

struct KeySound: Codable {
    let down: [String]
    let up: [String]
}
