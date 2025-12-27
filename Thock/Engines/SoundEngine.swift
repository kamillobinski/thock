import Foundation

// MARK: - UserDefaults Keys

extension UserDefaults {
    static let perDeviceVolumeKey = "perDeviceVolume"
}

// MARK: - Sound Engine

/// Orchestrates sound playback by coordinating between keyboard events,
/// sound selection, and the low-level audio manager.
final class SoundEngine {
    static let shared = SoundEngine()
    
    // MARK: - Properties
    
    /// Pitch variation range
    private var pitchVariation: Float = 0.0
    
    // MARK: - Initialization
    
    private init() {
        // Restore volume for the current audio device
        SoundManager.shared.applyPerDeviceVolume()
    }
    
    // MARK: - Sound Loading
    
    /// Preloads all sounds for a given mode into memory
    func preloadSounds(for mode: Mode) {
        SoundManager.shared.preloadSounds(for: mode)
    }
    
    // MARK: - Playback
    
    /// Plays sound for a keyboard event by selecting appropriate sound and delegating to manager
    /// - Parameters:
    ///   - keyCode: The keyboard key code
    ///   - isKeyDown: true for key press, false for key release
    ///   - latencyId: Optional UUID for latency measurement tracking
    func play(for keyCode: Int64, isKeyDown: Bool, latencyId: UUID? = nil) {
        // Don't play if app is disabled
        guard AppEngine.shared.isEnabled() else { return }
        
        recordLatencyCheckpoint(latencyId, point: .soundEngineInvoked)
        
        // Map key code to key type and get appropriate sounds
        let keyType = KeyMapper.fromKeyCode(keyCode)
        let keySoundList = isKeyDown
        ? ModeEngine.shared.getKeyDownSounds(for: keyType)
        : ModeEngine.shared.getKeyUpSounds(for: keyType)
        
        // Play random sound from the list
        if let soundFileName = keySoundList.randomElement() {
            recordLatencyCheckpoint(latencyId, point: .soundSelected)
            play(sound: soundFileName, latencyId: latencyId)
        }
    }
    
    /// Plays a specific sound by name
    /// - Parameters:
    ///   - name: The sound file name
    ///   - latencyId: Optional UUID for latency measurement tracking
    func play(sound name: String, latencyId: UUID? = nil) {
        SoundManager.shared.play(sound: name, pitchVariation: pitchVariation, latencyId: latencyId)
    }
    
    // MARK: - Volume Control
    
    /// Sets volume and persists it per audio device
    /// - Parameter volume: Volume level (0.0 to 1.0)
    func setVolume(_ volume: Float) {
        SoundManager.shared.setVolume(volume)
        
        // Save volume preference for current audio device
        let deviceUID = SoundManager.shared.getCurrentOutputDeviceUID()
        var perDeviceVolumes = UserDefaults.standard.dictionary(forKey: UserDefaults.perDeviceVolumeKey) as? [String: Float] ?? [:]
        perDeviceVolumes[deviceUID] = volume
        UserDefaults.standard.set(perDeviceVolumes, forKey: UserDefaults.perDeviceVolumeKey)
    }
    
    /// Gets current volume for the active audio device
    /// - Returns: Volume level (0.0 to 1.0)
    func getVolume() -> Float {
        let deviceUID = SoundManager.shared.getCurrentOutputDeviceUID()
        let perDeviceVolumes = UserDefaults.standard.dictionary(forKey: UserDefaults.perDeviceVolumeKey) as? [String: Float] ?? [:]
        
        // Return device-specific volume or fall back to global volume
        return perDeviceVolumes[deviceUID] ?? SoundManager.shared.getVolume()
    }
    
    // MARK: - Effects
    
    /// Sets pitch variation range for random pitch shifts
    /// - Parameter variation: Pitch variation range in semitones
    func setPitchVariation(_ variation: Float) {
        pitchVariation = variation
    }
    
    /// Gets current pitch variation setting
    /// - Returns: Pitch variation range
    func getPitchVariation() -> Float {
        return pitchVariation
    }
}
