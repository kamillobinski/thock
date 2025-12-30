import Foundation

// MARK: - Sound Engine

/// Orchestrates sound playback by coordinating between keyboard events,
/// sound selection, and the low-level audio manager.
final class SoundEngine {
    static let shared = SoundEngine()
    
    // MARK: - Initialization
    
    private init() {}
    
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
        let pitchVariation = SettingsEngine.shared.getPitchVariation()
        SoundManager.shared.play(sound: name, pitchVariation: pitchVariation, latencyId: latencyId)
    }
}
