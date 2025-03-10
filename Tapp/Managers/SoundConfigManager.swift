//
//  SoundConfigManager.swift
//  Tapp
//
//  Created by Kamil Łobiński on 10/03/2025.
//

import SwiftUI

class SoundConfigManager {
    static let shared = SoundConfigManager()
    
    private var soundFolder = "Resources/Sounds/"
    private var soundConfigFile = "config", soundConfigFileExtension: String = "json"
    private var soundConfig: SoundConfig?
    
    private init() {}
    
    func loadConfig() {
        if let jsonURL = Bundle.main.url(forResource: soundConfigFile, withExtension: soundConfigFileExtension, subdirectory: "\(soundFolder)\(SoundModeManager.shared.getMode().folderName)"),
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
    
    func getKeyUpSounds(for key: KeyType) -> [String] {
        return soundConfig?.sounds[key]?.up ?? []
    }
    
    func getKeyDownSounds(for key: KeyType) -> [String] {
        return soundConfig?.sounds[key]?.down ?? []
    }
}
