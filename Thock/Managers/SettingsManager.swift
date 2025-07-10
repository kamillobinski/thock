
import Foundation

/// Manages user-facing settings and syncs related system state as needed.
final class SettingsManager {
    static let shared = SettingsManager()
    static let defaultOpenAtLogin: Bool = false
    static let defaultDisableModifierKeys: Bool = false
    static let defaultIgnoreRapidKeyEvents: Bool = false
    static let defaultAutoMuteOnMusicPlayback: Bool = false

    
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
}

private extension UserDefaults {
    private enum Keys {
        static let openAtLogin = "openAtLogin"
        static let disableModifierKeys = "disableModifierKeys"
        static let ignoreRapidKeyEvents = "ignoreRapidKeyEvents"
        static let autoMuteOnMusicPlayback = "autoMuteOnMusicPlayback"
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
}
