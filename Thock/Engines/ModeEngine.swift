import Foundation

final class ModeEngine {
    static let shared = ModeEngine()
    
    private init() {}
    
    func apply(mode: Mode) {
        ModeManager.shared.setCurrentMode(mode)
        ModeConfigManager.shared.loadModeConfig(for: mode)
        SoundEngine.shared.preloadSounds(for: mode)
        SettingsEngine.shared.refreshMenu()
    }
    
    func loadInitialMode() {
        let mode = ModeManager.shared.getCurrentMode()
        ModeConfigManager.shared.loadModeConfig(for: mode)
        SoundEngine.shared.preloadSounds(for: mode)
    }
    
    func getKeyDownSounds(for key: String) -> [String] {
        return ModeConfigManager.shared.getKeyDownSounds(for: key)
    }
    
    func getKeyUpSounds(for key: String) -> [String] {
        return ModeConfigManager.shared.getKeyUpSounds(for: key)
    }
    
    func getModeCurrentMode() -> Mode {
        return ModeManager.shared.getCurrentMode()
    }
}
