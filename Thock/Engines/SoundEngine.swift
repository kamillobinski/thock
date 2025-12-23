import Foundation

extension UserDefaults {
    static let volumeKey = "appVolume"
    static let perDeviceVolumeKey = "perDeviceVolume"
}

final class SoundEngine {
    static let shared = SoundEngine()
    
    private init() {
        SoundManager.shared.applyPerDeviceVolume()
    }
    private var pitchVariation: Float = 0.0
    
    
    func preloadSounds(for mode: Mode) {
        SoundManager.shared.preloadSounds(for: mode)
    }
    
    /// Plays sound for a key press event.
    func play(for keyCode: Int64, isKeyDown: Bool, latencyId: UUID? = nil) {
        guard AppEngine.shared.isEnabled() else { return }
        
        recordLatencyCheckpoint(latencyId, point: .soundEngineInvoked)
        
        let keyType = KeyMapper.fromKeyCode(keyCode)
        let keySoundList = isKeyDown
        ? ModeEngine.shared.getKeyDownSounds(for: keyType)
        : ModeEngine.shared.getKeyUpSounds(for: keyType)
        
        if let soundFileName = keySoundList.randomElement() {
            recordLatencyCheckpoint(latencyId, point: .soundSelected)
            
            let randomPitchOffset = Float.random(in: -pitchVariation...pitchVariation)
            SoundManager.shared.setGlobalPitch(randomPitchOffset)
            play(sound: soundFileName, latencyId: latencyId)
        }
    }
    
    func play(sound name: String, latencyId: UUID? = nil) {
        SoundManager.shared.play(sound: name, latencyId: latencyId)
    }
    
    func setVolume(_ volume: Float) {
        SoundManager.shared.setVolume(volume)
        let deviceUID = SoundManager.shared.getCurrentOutputDeviceUID()
        var perDeviceVolumes = UserDefaults.standard.dictionary(forKey: UserDefaults.perDeviceVolumeKey) as? [String: Float] ?? [:]
        perDeviceVolumes[deviceUID] = volume
        UserDefaults.standard.set(perDeviceVolumes, forKey: UserDefaults.perDeviceVolumeKey)
    }
    
    func getVolume() -> Float {
        let deviceUID = SoundManager.shared.getCurrentOutputDeviceUID()
        let perDeviceVolumes = UserDefaults.standard.dictionary(forKey: UserDefaults.perDeviceVolumeKey) as? [String: Float] ?? [:]
        return perDeviceVolumes[deviceUID] ?? SoundManager.shared.getVolume()
    }
    
    func setPitchVariation(_ variation: Float) {
        pitchVariation = variation
    }
    
    func getPitchVariation() -> Float {
        return pitchVariation
    }
    
}
