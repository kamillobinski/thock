//
//  ModeConfigManager.swift
//  Thock
//
//  Created by Kamil Łobiński on 10/03/2025.
//

import SwiftUI

class ModeConfigManager {
    static let shared = ModeConfigManager()
    
    private let soundConfigFileExtension: String = "json"
    private var soundConfig: SoundConfig?
    
    private init() {}
    
    /// Loads and decodes the sound configuration for a given mode.
    ///
    /// This function looks for a `config.json` file in the mode's directory—either inside the app bundle (for built-in modes)
    /// or in the user's Application Support directory (for custom modes). It decodes the file into a `SoundConfig` object,
    /// which is then used to retrieve sound mappings at runtime.
    ///
    /// - Parameter mode: The `Mode` whose configuration should be loaded. Must have a valid `.path` to a directory containing `config.json`.
    /// - Note: If the config file is missing or fails to decode, sound mapping will silently fail (fallbacks will apply).
    func loadModeConfig(for mode: Mode) {
        let isCustom = mode.path.hasPrefix("CustomSounds/")
        let fileURL: URL?
        
        if isCustom {
            fileURL = FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Thock/\(mode.path)/config.json")
        } else {
            fileURL = Bundle.main.url(forResource: "config", withExtension: "json", subdirectory: mode.path)
        }
        
        guard let url = fileURL else {
            print("Sound config file not found for mode: \(mode.name)")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            soundConfig = try JSONDecoder().decode(SoundConfig.self, from: data)
            print("Loaded sound config for mode: \(mode.name)")
        } catch {
            print("Failed to decode SoundConfig for mode \(mode.name): \(error)")
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
