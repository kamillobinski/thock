import Foundation

struct SoundpackManifest: Decodable {
    let version: String
    let lastUpdated: String
    let soundpacks: SoundpackManifestCategories
}

struct SoundpackManifestCategories: Decodable {
    let keyboard: [SoundpackRegistryEntry]
    let mouse: [SoundpackRegistryEntry]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var kb = try container.decodeIfPresent([SoundpackRegistryEntry].self, forKey: .keyboard) ?? []
        var ms = try container.decodeIfPresent([SoundpackRegistryEntry].self, forKey: .mouse) ?? []
        for i in kb.indices { kb[i].category = "keyboard" }
        for i in ms.indices { ms[i].category = "mouse" }
        keyboard = kb
        mouse = ms
    }
    
    private enum CodingKeys: String, CodingKey {
        case keyboard, mouse
    }
}

struct SoundpackRegistryEntry: Decodable, Identifiable {
    let id: UUID
    let metadata: SoundpackRegistryMetadata
    let content: SoundpackRegistryContent
    let download: SoundpackRegistryDownload
    let license: License
    var category: String = "keyboard"
    
    private enum CodingKeys: String, CodingKey {
        case id, metadata, content, download, license
    }
}

struct SoundpackRegistryMetadata: Decodable {
    let name: String
    let brand: String
    let author: String
    let supportsKeyUp: Bool
}

struct SoundpackRegistryContent: Decodable {
    let path: String
}

struct SoundpackRegistryDownload: Decodable {
    let url: String
    let size: Int
}
