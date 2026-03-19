import Foundation
import OSLog

final class SoundpackEngine {
    static let shared = SoundpackEngine()
    
    private init() {}
    
    // MARK: - Apply
    
    func applyKeyboard(soundpack: Soundpack) {
        guard isSoundpackAvailable(soundpack) else {
            Logger.engine.warning("Keyboard soundpack '\(soundpack.name)' is no longer available — falling back")
            handleMissingKeyboardSoundpack()
            return
        }
        SoundpackManager.shared.setCurrentKeyboardSoundpack(soundpack)
        SoundpackConfigManager.shared.loadConfig(for: soundpack)
        SoundEngine.shared.preloadSounds(for: soundpack)
        SettingsEngine.shared.refreshMenu()
    }
    
    func applyMouse(soundpack: Soundpack) {
        guard isSoundpackAvailable(soundpack) else {
            Logger.engine.warning("Mouse soundpack '\(soundpack.name)' is no longer available — falling back")
            handleMissingMouseSoundpack()
            return
        }
        SoundpackManager.shared.setCurrentMouseSoundpack(soundpack)
        SoundpackConfigManager.shared.loadMouseConfig(for: soundpack)
        if let config = SoundpackConfigManager.shared.getMouseConfig() {
            SoundEngine.shared.preloadMouseSounds(for: soundpack, config: config)
        }
        SettingsEngine.shared.refreshMenu()
    }
    
    // MARK: - Post-Removal
    
    func reloadAfterRemoval(for category: String) {
        if category == "mouse" {
            handleMissingMouseSoundpack()
        } else {
            handleMissingKeyboardSoundpack()
        }
    }
    
    // MARK: - Initial Load
    
    func loadInitialSoundpacks() {
        if let keyboard = SoundpackManager.shared.getCurrentKeyboardSoundpack() {
            if isSoundpackAvailable(keyboard) {
                SoundpackConfigManager.shared.loadConfig(for: keyboard)
                SoundEngine.shared.preloadSounds(for: keyboard)
            } else {
                handleMissingKeyboardSoundpack()
            }
        }
        
        if let mouse = SoundpackManager.shared.getCurrentMouseSoundpack() {
            if isSoundpackAvailable(mouse) {
                SoundpackConfigManager.shared.loadMouseConfig(for: mouse)
                if let config = SoundpackConfigManager.shared.getMouseConfig() {
                    SoundEngine.shared.preloadMouseSounds(for: mouse, config: config)
                }
            } else {
                handleMissingMouseSoundpack()
            }
        }
    }
    
    // MARK: - Sound Lookups
    
    func getKeyDownSounds(for key: String) -> [String] {
        return SoundpackConfigManager.shared.getKeyDownSounds(for: key)
    }
    
    func getKeyUpSounds(for key: String) -> [String] {
        return SoundpackConfigManager.shared.getKeyUpSounds(for: key)
    }
    
    func getCurrentKeyboardSoundpack() -> Soundpack? {
        return SoundpackManager.shared.getCurrentKeyboardSoundpack()
    }
    
    func getCurrentMouseSoundpack() -> Soundpack? {
        return SoundpackManager.shared.getCurrentMouseSoundpack()
    }
    
    // MARK: - Availability
    
    private func isSoundpackAvailable(_ soundpack: Soundpack) -> Bool {
        let dir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Thock/\(soundpack.path)")
        return FileManager.default.fileExists(atPath: dir.path)
    }
    
    private func handleMissingKeyboardSoundpack() {
        SoundpackManager.shared.reloadCurrentSoundpacks()
        SoundpackConfigManager.shared.clearConfig()
        
        if let fallback = SoundpackManager.shared.getCurrentKeyboardSoundpack(),
           isSoundpackAvailable(fallback) {
            SoundpackConfigManager.shared.loadConfig(for: fallback)
            SoundEngine.shared.preloadSounds(for: fallback)
        }
        
        SettingsEngine.shared.refreshMenu()
    }
    
    private func handleMissingMouseSoundpack() {
        SoundpackManager.shared.reloadCurrentSoundpacks()
        SoundpackConfigManager.shared.clearMouseConfig()
        
        if let fallback = SoundpackManager.shared.getCurrentMouseSoundpack(),
           isSoundpackAvailable(fallback) {
            SoundpackConfigManager.shared.loadMouseConfig(for: fallback)
            if let config = SoundpackConfigManager.shared.getMouseConfig() {
                SoundEngine.shared.preloadMouseSounds(for: fallback, config: config)
            }
        }
        
        SettingsEngine.shared.refreshMenu()
    }
}
