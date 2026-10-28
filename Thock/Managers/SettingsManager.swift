
import Foundation

/// Manages user-facing settings and syncs related system state as needed.
final class SettingsManager {
    static let shared = SettingsManager()
    static let defaultOpenAtLogin: Bool = false
    static let defaultDisableModifierKeys: Bool = false
    static let defaultIgnoreRapidKeyEvents: Bool = false
    static let defaultAutoMuteOnMusicPlayback: Bool = false
    static let defaultIdleTimeoutSeconds: TimeInterval = 10.0
    static let defaultAudioBufferSize: UInt32 = 256
    static let defaultSelectedAudioDeviceUID: String? = nil
    static let defaultPerDeviceVolumes: [String: Float] = [:]
    static let defaultKeyboardVolume: Float = 1.0
    static let defaultMouseVolume: Float = 1.0
    static let defaultConstantVolumeEnabled: Bool = false
    static let defaultPitchVariation: Float = 0.0
    static let defaultMouseSoundEnabled: Bool = false
    static let defaultSoftClippingEnabled: Bool = false
    static let defaultAutoEnableOnHeadphone: Bool = false
    static let defaultSpatialAudioEnabled: Bool = false
    static let defaultSpatialWidth: Float = SpatialMath.defaultWidth
    
    
    private init() {}
    
    /// Whether the app should launch at login.
    /// Automatically updates the system login item registration.
    var openAtLogin: Bool {
        get { UserDefaults.openAtLogin }
        set { UserDefaults.openAtLogin = newValue }
    }
    
    /// Whether modifier keys should be ignored in sound playback.
    var disableModifierKeys: Bool {
        get { UserDefaults.disableModifierKeys }
        set { UserDefaults.disableModifierKeys = newValue }
    }
    
    /// Whether to filter out key events that occur too rapidly in succession.
    var ignoreRapidKeyEvents: Bool {
        get { UserDefaults.ignoreRapidKeyEvents }
        set { UserDefaults.ignoreRapidKeyEvents = newValue }
    }
    
    /// Whether to mute keyboard sounds when music is playing.
    var autoMuteOnMusicPlayback: Bool {
        get { UserDefaults.autoMuteOnMusicPlayback }
        set { UserDefaults.autoMuteOnMusicPlayback = newValue }
    }
    
    /// Number of seconds of inactivity before stopping the audio queue to save CPU.
    /// Set to 0 to disable idle timeout (queue always runs).
    var idleTimeoutSeconds: TimeInterval {
        get { UserDefaults.idleTimeoutSeconds }
        set { UserDefaults.idleTimeoutSeconds = newValue }
    }
    
    /// Audio buffer size in frames. Lower values reduce latency but use more CPU.
    var audioBufferSize: UInt32 {
        get { UserDefaults.audioBufferSize }
        set { UserDefaults.audioBufferSize = newValue }
    }
    
    /// Selected audio output device UID. nil means use system default.
    var selectedAudioDeviceUID: String? {
        get { UserDefaults.selectedAudioDeviceUID }
        set { UserDefaults.selectedAudioDeviceUID = newValue }
    }
    
    /// Per-device volume levels. Dictionary keyed by device UID.
    var perDeviceVolumes: [String: Float] {
        get { UserDefaults.perDeviceVolumes }
        set { UserDefaults.perDeviceVolumes = newValue }
    }

    /// Keyboard level relative to the master volume, shared across output devices.
    var keyboardVolume: Float {
        get { UserDefaults.keyboardVolume }
        set { UserDefaults.keyboardVolume = newValue }
    }

    /// Mouse level relative to the master volume, shared across output devices.
    var mouseVolume: Float {
        get { UserDefaults.mouseVolume }
        set { UserDefaults.mouseVolume = newValue }
    }
    
    /// Whether Thock compensates for output device volume changes.
    var constantVolumeEnabled: Bool {
        get { UserDefaults.constantVolumeEnabled }
        set { UserDefaults.constantVolumeEnabled = newValue }
    }

    /// Pitch variation range in semitones for random pitch shifts.
    var pitchVariation: Float {
        get { UserDefaults.pitchVariation }
        set { UserDefaults.pitchVariation = newValue }
    }
    
    /// Whether to play sound when clicking the mouse.
    var mouseSoundEnabled: Bool {
        get { UserDefaults.mouseSoundEnabled }
        set { UserDefaults.mouseSoundEnabled = newValue }
    }

    /// Whether to soften peaks in the final mix of keyboard and mouse sounds.
    var softClippingEnabled: Bool {
        get { UserDefaults.softClippingEnabled }
        set { UserDefaults.softClippingEnabled = newValue }
    }
    
    /// Whether to position sounds by key and cursor location.
    var spatialAudioEnabled: Bool {
        get { UserDefaults.spatialAudioEnabled }
        set { UserDefaults.spatialAudioEnabled = newValue }
    }
    
    /// Azimuth in degrees of the keyboard and screen edges when spatial audio is on.
    var spatialWidth: Float {
        get { UserDefaults.spatialWidth }
        set { UserDefaults.spatialWidth = newValue }
    }
    
    /// Whether to auto-enable Thock when headphones are connected.
    var autoEnableOnHeadphone: Bool {
        get { UserDefaults.autoEnableOnHeadphone }
        set { UserDefaults.autoEnableOnHeadphone = newValue }
    }
    
    /// Whether keyboard cleaning mode is active. NOT PERSISTED
    var isCleaningMode: Bool {
        get { UtilityManager.shared.isCleaningMode }
        set { UtilityManager.shared.isCleaningMode = newValue }
    }
}

private extension UserDefaults {
    private enum Keys {
        static let openAtLogin = "openAtLogin"
        static let disableModifierKeys = "disableModifierKeys"
        static let ignoreRapidKeyEvents = "ignoreRapidKeyEvents"
        static let autoMuteOnMusicPlayback = "autoMuteOnMusicPlayback"
        static let idleTimeoutSeconds = "idleTimeoutSeconds"
        static let audioBufferSize = "audioBufferSize"
        static let selectedAudioDeviceUID = "selectedAudioDeviceUID"
        static let perDeviceVolumes = "perDeviceVolume"
        static let keyboardVolume = "keyboardVolume"
        static let mouseVolume = "mouseVolume"
        static let constantVolumeEnabled = "constantVolumeEnabled"
        static let pitchVariation = "pitchVariation"
        static let mouseSoundEnabled = "mouseSoundEnabled"
        static let softClippingEnabled = "softClippingEnabled"
        static let autoEnableOnHeadphone = "autoEnableOnHeadphone"
        static let spatialAudioEnabled = "spatialAudioEnabled"
        static let spatialWidth = "spatialWidth"
    }
    
    static var openAtLogin: Bool {
        get {
            if standard.object(forKey: Keys.openAtLogin) == nil {
                return SettingsManager.defaultOpenAtLogin
            }
            return standard.bool(forKey: Keys.openAtLogin)
        }
        set {
            standard.set(newValue, forKey: Keys.openAtLogin)
        }
    }
    
    static var disableModifierKeys: Bool {
        get {
            if standard.object(forKey: Keys.disableModifierKeys) == nil {
                return SettingsManager.defaultDisableModifierKeys
            }
            return standard.bool(forKey: Keys.disableModifierKeys)
        }
        set {
            standard.set(newValue, forKey: Keys.disableModifierKeys)
        }
    }
    
    static var ignoreRapidKeyEvents: Bool {
        get {
            if standard.object(forKey: Keys.ignoreRapidKeyEvents) == nil {
                return SettingsManager.defaultIgnoreRapidKeyEvents
            }
            return standard.bool(forKey: Keys.ignoreRapidKeyEvents)
        }
        set {
            standard.set(newValue, forKey: Keys.ignoreRapidKeyEvents)
        }
    }
    
    static var autoMuteOnMusicPlayback: Bool {
        get {
            if standard.object(forKey: Keys.autoMuteOnMusicPlayback) == nil {
                return SettingsManager.defaultAutoMuteOnMusicPlayback
            }
            return standard.bool(forKey: Keys.autoMuteOnMusicPlayback)
        }
        set {
            standard.set(newValue, forKey: Keys.autoMuteOnMusicPlayback)
        }
    }
    
    static var idleTimeoutSeconds: TimeInterval {
        get {
            if standard.object(forKey: Keys.idleTimeoutSeconds) == nil {
                return SettingsManager.defaultIdleTimeoutSeconds
            }
            return standard.double(forKey: Keys.idleTimeoutSeconds)
        }
        set {
            standard.set(newValue, forKey: Keys.idleTimeoutSeconds)
        }
    }
    
    static var audioBufferSize: UInt32 {
        get {
            if standard.object(forKey: Keys.audioBufferSize) == nil {
                return SettingsManager.defaultAudioBufferSize
            }
            return UInt32(standard.integer(forKey: Keys.audioBufferSize))
        }
        set {
            standard.set(newValue, forKey: Keys.audioBufferSize)
        }
    }
    
    static var selectedAudioDeviceUID: String? {
        get {
            if standard.object(forKey: Keys.selectedAudioDeviceUID) == nil {
                return SettingsManager.defaultSelectedAudioDeviceUID
            }
            return standard.string(forKey: Keys.selectedAudioDeviceUID)
        }
        set {
            standard.set(newValue, forKey: Keys.selectedAudioDeviceUID)
        }
    }
    
    static var perDeviceVolumes: [String: Float] {
        get {
            if standard.object(forKey: Keys.perDeviceVolumes) == nil {
                return SettingsManager.defaultPerDeviceVolumes
            }
            return standard.dictionary(forKey: Keys.perDeviceVolumes) as? [String: Float] ?? SettingsManager.defaultPerDeviceVolumes
        }
        set {
            standard.set(newValue, forKey: Keys.perDeviceVolumes)
        }
    }
    
    static var keyboardVolume: Float {
        get {
            guard standard.object(forKey: Keys.keyboardVolume) != nil else {
                return SettingsManager.defaultKeyboardVolume
            }
            return VolumeLevels.clamped(standard.float(forKey: Keys.keyboardVolume))
        }
        set {
            standard.set(VolumeLevels.clamped(newValue), forKey: Keys.keyboardVolume)
        }
    }

    static var mouseVolume: Float {
        get {
            guard standard.object(forKey: Keys.mouseVolume) != nil else {
                return SettingsManager.defaultMouseVolume
            }
            return VolumeLevels.clamped(standard.float(forKey: Keys.mouseVolume))
        }
        set {
            standard.set(VolumeLevels.clamped(newValue), forKey: Keys.mouseVolume)
        }
    }

    static var constantVolumeEnabled: Bool {
        get {
            if standard.object(forKey: Keys.constantVolumeEnabled) == nil {
                return SettingsManager.defaultConstantVolumeEnabled
            }
            return standard.bool(forKey: Keys.constantVolumeEnabled)
        }
        set {
            standard.set(newValue, forKey: Keys.constantVolumeEnabled)
        }
    }

    static var pitchVariation: Float {
        get {
            if standard.object(forKey: Keys.pitchVariation) == nil {
                return SettingsManager.defaultPitchVariation
            }
            return standard.float(forKey: Keys.pitchVariation)
        }
        set {
            standard.set(newValue, forKey: Keys.pitchVariation)
        }
    }
    
    static var mouseSoundEnabled: Bool {
        get {
            if standard.object(forKey: Keys.mouseSoundEnabled) == nil {
                return SettingsManager.defaultMouseSoundEnabled
            }
            return standard.bool(forKey: Keys.mouseSoundEnabled)
        }
        set {
            standard.set(newValue, forKey: Keys.mouseSoundEnabled)
        }
    }
    
    static var softClippingEnabled: Bool {
        get {
            guard standard.object(forKey: Keys.softClippingEnabled) != nil else {
                return SettingsManager.defaultSoftClippingEnabled
            }
            return standard.bool(forKey: Keys.softClippingEnabled)
        }
        set {
            standard.set(newValue, forKey: Keys.softClippingEnabled)
        }
    }

    static var autoEnableOnHeadphone: Bool {
        get {
            if standard.object(forKey: Keys.autoEnableOnHeadphone) == nil {
                return SettingsManager.defaultAutoEnableOnHeadphone
            }
            return standard.bool(forKey: Keys.autoEnableOnHeadphone)
        }
        set {
            standard.set(newValue, forKey: Keys.autoEnableOnHeadphone)
        }
    }
    
    static var spatialAudioEnabled: Bool {
        get {
            if standard.object(forKey: Keys.spatialAudioEnabled) == nil {
                return SettingsManager.defaultSpatialAudioEnabled
            }
            return standard.bool(forKey: Keys.spatialAudioEnabled)
        }
        set {
            standard.set(newValue, forKey: Keys.spatialAudioEnabled)
        }
    }
    
    static var spatialWidth: Float {
        get {
            if standard.object(forKey: Keys.spatialWidth) == nil {
                return SettingsManager.defaultSpatialWidth
            }
            return SpatialMath.clampWidth(standard.float(forKey: Keys.spatialWidth))
        }
        set {
            standard.set(SpatialMath.clampWidth(newValue), forKey: Keys.spatialWidth)
        }
    }
}
