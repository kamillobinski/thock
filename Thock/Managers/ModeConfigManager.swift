//
//  ModeConfigManager.swift
//  Thock
//
//  Created by Kamil Łobiński on 10/03/2025.
//

import SwiftUI

class ModeConfigManager {
    static let shared = ModeConfigManager()
    
    private let soundConfigFile = "config", soundConfigFileExtension: String = "json"
    private var soundConfig: SoundConfig?
    
    private init() {}
    
    /// Loads the sound configuration for a given mode from a JSON file.
    /// - Parameter mode: The `Mode` whose configuration should be loaded.
    func loadModeConfig(for mode: Mode) {
        if let jsonURL = Bundle.main.url(forResource: soundConfigFile, withExtension: soundConfigFileExtension, subdirectory: mode.path),
           let jsonData = try? Data(contentsOf: jsonURL) {
            let decoder = JSONDecoder()
            do {
                soundConfig = try decoder.decode(SoundConfig.self, from: jsonData)
            } catch {
                print("Failed to decode sound config: \(error)")
            }
        } else {
            print("Sound config file not found!")
        }
    }
    
    func supportsKeyUpSounds() -> Bool {
        return soundConfig?.supportsKeyUp ?? false
    }
    
    /// Retrieves the "KeyUp" sounds for a given key.
    /// - If a sound array exists for the key, it is returned.
    /// - If no sound array is found, falls back to the default key sound array.
    /// - If no default sound array exists, returns an empty array.
    /// - Parameter key: The key for which to retrieve the "KeyUp" sounds.
    /// - Returns: An array of sound file names, or an empty array if none are found.
    func getKeyUpSounds(for key: String) -> [String] {
        return soundConfig?.sounds[key]?.up ?? soundConfig?.sounds[KeyMapper.keyCodeNotFound]?.up ?? []
    }
    
    /// Retrieves the "KeyDown" sounds for a given key.
    /// - If a sound array exists for the key, it is returned.
    /// - If no sound array is found, falls back to the default key sound array.
    /// - If no default sound array exists, returns an empty array.
    /// - Parameter key: The key for which to retrieve the "KeyDown" sounds.
    /// - Returns: An array of sound file names, or an empty array if none are found.
    func getKeyDownSounds(for key: String) -> [String] {
        return soundConfig?.sounds[key]?.down ?? soundConfig?.sounds[KeyMapper.keyCodeNotFound]?.down ?? []
    }
}
