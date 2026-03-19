import Foundation

struct SoundpackConfig: Decodable {
    let id: UUID
    let metadata: SoundpackConfigMetadata
    let license: License
    let sounds: [String: KeySound]
}

struct SoundpackConfigMetadata: Decodable {
    let name: String
    let brand: String
    let author: String
    let category: String
    let supportsKeyUp: Bool
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decode(String.self, forKey: .brand)
        author = try container.decode(String.self, forKey: .author)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "keyboard"
        supportsKeyUp = try container.decodeIfPresent(Bool.self, forKey: .supportsKeyUp) ?? false
    }
    
    private enum CodingKeys: String, CodingKey {
        case name, brand, author, category, supportsKeyUp
    }
}

struct License: Decodable {
    let type: String
    let url: String
}

struct KeySound: Decodable {
    let down: [String]
    let up: [String]
}
