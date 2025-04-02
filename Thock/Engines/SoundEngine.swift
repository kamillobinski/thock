//
//  SoundEngine.swift
//  Thock
//
//  Created by Kamil Łobiński on 29/03/2025.
//

import Foundation

final class SoundEngine {
    static let shared = SoundEngine()
    
    private init() {}
    private var pitchVariation: Float = 0.0
    
    
    func preloadSounds(for mode: Mode) {
        print("Preload sounds")
        SoundManager.shared.preloadSounds(for: mode)
    }
    
    /// Plays sound for a key press event.
    func play(for keyCode: Int64, isKeyDown: Bool) {
        guard AppEngine.shared.isEnabled() else { return }
        print("Play sound for keyCode: \(keyCode)")
        let keyType = KeyMapper.fromKeyCode(keyCode)
        let keySoundList = isKeyDown
        ? ModeEngine.shared.getKeyDownSounds(for: keyType)
        : ModeEngine.shared.getKeyUpSounds(for: keyType)
        
        if let soundFileName = keySoundList.randomElement() {
            let randomPitchOffset = Float.random(in: -pitchVariation...pitchVariation)
            SoundManager.shared.setGlobalPitch(randomPitchOffset)
            play(sound: soundFileName)
        } else {
            // print("Warning: (keydown: \(isKeyDown)) No available sound for keyCode: \(keyCode)")
        }
    }
    
    func play(sound name: String) {
        print("Play sound: \(name)")
        SoundManager.shared.play(sound: name)
    }
    
    func setVolume(_ volume: Float) {
        print("Set volume: \(volume)")
        SoundManager.shared.setVolume(volume)
    }
    
    func getVolume() -> Float {
        print("Get volume")
        return SoundManager.shared.getVolume()
    }
    
    func setPitchVariation(_ variation: Float) {
        print("Set pitch variation: \(variation)")
        pitchVariation = variation
    }
    
    func getPitchVariation() -> Float {
        return pitchVariation
    }
    
}
