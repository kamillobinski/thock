//
//  ModeEngine.swift
//  Thock
//
//  Created by Kamil Łobiński on 28/03/2025.
//

import Foundation

final class ModeEngine {
    static let shared = ModeEngine()
    
    private init() {}
    
    func apply(mode: Mode) {
        print("Apply mode: \(mode.name)")
        ModeManager.shared.setCurrentMode(mode)
        ModeConfigManager.shared.loadModeConfig(for: mode)
        SoundEngine.shared.preloadSounds(for: mode)
        SettingsEngine.shared.refreshMenu()
    }
    
    func loadInitialMode() {
        print("Load initial mode config")
        let mode = ModeManager.shared.getCurrentMode()
        ModeConfigManager.shared.loadModeConfig(for: mode)
        SoundEngine.shared.preloadSounds(for: mode)
    }
    
    func getKeyDownSounds(for key: String) -> [String] {
        print("Get key down sounds for \(key)")
        return ModeConfigManager.shared.getKeyDownSounds(for: key)
    }
    
    func getKeyUpSounds(for key: String) -> [String] {
        print("Get key up sounds for \(key)")
        return ModeConfigManager.shared.getKeyUpSounds(for: key)
    }
    
    func getModeCurrentMode() -> Mode {
        print("Get current mode")
        return ModeManager.shared.getCurrentMode()
    }
}
