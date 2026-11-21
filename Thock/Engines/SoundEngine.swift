import Foundation

// MARK: - Sound Engine

/// Orchestrates sound playback by coordinating between keyboard events,
/// sound selection, and the low-level audio manager.
final class SoundEngine {
    static let shared = SoundEngine()
    
    /// Sounds played last for a press and for a release. Only touched on SoundManager.playbackQueue.
    private var lastKeyDownSound: String?
    private var lastKeyUpSound: String?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Sound Loading
    
    func preloadSounds(for soundpack: Soundpack) {
        SoundManager.shared.preloadSounds(for: soundpack)
    }
    
    func preloadMouseSounds(for soundpack: Soundpack, config: SoundpackConfig) {
        SoundManager.shared.preloadMouseSoundsFromPack(for: soundpack, config: config)
    }
    
    // MARK: - Playback
    
    /// Plays sound for a keyboard event by selecting appropriate sound and delegating to manager
    /// - Parameters:
    ///   - keyCode: The keyboard key code
    ///   - isKeyDown: true for key press, false for key release
    ///   - layout: Physical layout captured from the originating keyboard event
    ///   - latencyId: Optional UUID for latency measurement tracking
    func play(for keyCode: Int64, isKeyDown: Bool, layout: KeyLayout.Physical = .ansi, latencyId: UUID? = nil) {
        // Don't play if app is disabled
        guard AppEngine.shared.isEnabled() else { return }
        
        recordLatencyCheckpoint(latencyId, point: .soundEngineInvoked)
        
        // Map key code to key type and get appropriate sounds
        let keyType = KeyMapper.fromKeyCode(keyCode)
        let keySoundList = isKeyDown
        ? SoundpackEngine.shared.getKeyDownSounds(for: keyType)
        : SoundpackEngine.shared.getKeyUpSounds(for: keyType)
        
        // Play random sound from the list
        let lastSound = isKeyDown ? lastKeyDownSound : lastKeyUpSound
        if let soundFileName = Self.pickSound(from: keySoundList, avoiding: lastSound) {
            if isKeyDown {
                lastKeyDownSound = soundFileName
            } else {
                lastKeyUpSound = soundFileName
            }
            recordLatencyCheckpoint(latencyId, point: .soundSelected)
            play(sound: soundFileName, latencyId: latencyId, position: KeyLayout.position(for: keyCode, width: SettingsEngine.shared.getSpatialWidth(), layout: layout))
        }
    }
    
    /// Picks a random sound, skipping the one that played last when there is another to choose.
    /// Hearing the same sample twice in a row is what makes sampled typing sound mechanical.
    static func pickSound(from sounds: [String], avoiding lastSound: String?) -> String? {
        let fresh = sounds.filter { $0 != lastSound }
        return (fresh.isEmpty ? sounds : fresh).randomElement()
    }
    
    /// Plays a specific sound by name
    /// - Parameters:
    ///   - name: The sound file name
    ///   - latencyId: Optional UUID for latency measurement tracking
    ///   - position: Where the sound sits in space when spatial audio is on
    func play(sound name: String, latencyId: UUID? = nil, position: SoundPosition? = nil) {
        let pitchVariation = SettingsEngine.shared.getPitchVariation()
        SoundManager.shared.play(sound: name, pitchVariation: pitchVariation, latencyId: latencyId, position: position)
    }
}
