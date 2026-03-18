import Foundation
import OSLog

struct SoundpackDatabase {
    let soundpacks: [Soundpack]
    
    init() {
        self.soundpacks = SoundpackDatabase.loadInstalled()
    }
    
    func getSoundpack(by id: UUID) -> Soundpack? {
        soundpacks.first { $0.id == id }
    }
    
    func getSoundpacks(for category: String) -> [Soundpack] {
        soundpacks.filter { $0.category == category }
    }
    
    func getBrands(for category: String) -> [String] {
        Array(Set(soundpacks.filter { $0.category == category }.map { $0.brand })).sorted()
    }
    
    func getSoundpacks(for brand: String, category: String) -> [Soundpack] {
        soundpacks
            .filter { $0.brand == brand && $0.category == category }
            .sorted { $0.name < $1.name }
    }
    
    static func loadInstalled() -> [Soundpack] {
        let basePath = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Thock/Soundpacks", isDirectory: true)
        
        guard FileManager.default.fileExists(atPath: basePath.path) else { return [] }
        
        var result: [Soundpack] = []
        
        do {
            let subdirs = try FileManager.default.contentsOfDirectory(
                at: basePath,
                includingPropertiesForKeys: nil
            ).filter { $0.hasDirectoryPath }
            
            for folderURL in subdirs {
                let configURL = folderURL.appendingPathComponent("config.json")
                guard let data = try? Data(contentsOf: configURL),
                      let config = try? JSONDecoder().decode(SoundpackConfig.self, from: data)
                else { continue }
                
                result.append(Soundpack(
                    id: config.id,
                    name: config.metadata.name,
                    brand: config.metadata.brand,
                    author: config.metadata.author,
                    category: config.metadata.category,
                    path: "Soundpacks/\(folderURL.lastPathComponent)/"
                ))
            }
        } catch {
            Logger.engine.error("Failed to load soundpacks: \(error)")
        }
        
        return result
    }
}
