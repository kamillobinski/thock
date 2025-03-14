//
//  ModeConfig.swift
//  Thock
//
//  Created by Kamil Łobiński on 10/03/2025.
//

import Foundation

struct SoundConfig: Codable {
    let name: String
    let source: String
    let license: License
    let supportsKeyUp: Bool
    let sounds: [String: KeySound]
    
    // Custom Decoder to Map Dictionary Keys to KeyType Enum
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        source = try container.decode(String.self, forKey: .source)
        license = try container.decode(License.self, forKey: .license)
        supportsKeyUp = try container.decode(Bool.self, forKey: .supportsKeyUp)
        sounds = try container.decode([String: KeySound].self, forKey: .sounds)
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
