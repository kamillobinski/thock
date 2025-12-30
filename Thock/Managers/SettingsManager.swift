
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
    
    
    private init() {}
    
    /// Whether the app should launch at login.
    /// Automatically updates the system login item registration.
    var openAtLogin: Bool {
        get { UserDefaults.openAtLogin }
        set {
            UserDefaults.openAtLogin = newValue
        }
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
}
