import Foundation
import OSLog

class SoundpackConfigManager {
    static let shared = SoundpackConfigManager()
    
    private var keyboardConfig: SoundpackConfig?
    private var mouseConfig: SoundpackConfig?
    
    private init() {}
    
    // MARK: - Keyboard
    
    func loadConfig(for soundpack: Soundpack) {
        keyboardConfig = loadConfig(at: soundpack.path, name: soundpack.name)
    }
    
    func clearConfig() {
        keyboardConfig = nil
    }
    
    func supportsKeyUpSounds() -> Bool {
        return keyboardConfig?.metadata.supportsKeyUp ?? false
    }
    
    func getKeyDownSounds(for key: String) -> [String] {
        return keyboardConfig?.sounds[key]?.down
        ?? keyboardConfig?.sounds[KeyMapper.keyCodeNotFound]?.down
        ?? []
    }
    
    func getKeyUpSounds(for key: String) -> [String] {
        return keyboardConfig?.sounds[key]?.up
        ?? keyboardConfig?.sounds[KeyMapper.keyCodeNotFound]?.up
        ?? []
    }
    
    // MARK: - Mouse
    
    func loadMouseConfig(for soundpack: Soundpack) {
        mouseConfig = loadConfig(at: soundpack.path, name: soundpack.name)
    }
    
    func clearMouseConfig() {
        mouseConfig = nil
    }
    
    func getMouseConfig() -> SoundpackConfig? {
        return mouseConfig
    }
    
    // MARK: - Private
    
    private func loadConfig(at path: String, name: String) -> SoundpackConfig? {
        let fileURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Thock/\(path)config.json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Logger.engine.warning("Config not found for soundpack: '\(name)'")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let config = try JSONDecoder().decode(SoundpackConfig.self, from: data)
            Logger.engine.info("Loaded config for soundpack: '\(name)'")
            return config
        } catch {
            Logger.engine.error("Failed to decode SoundpackConfig for '\(name)': \(error)")
            return nil
        }
    }
}
