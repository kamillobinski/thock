//
//  SettingsManager.swift
//  Thock
//
//  Created by Kamil Łobiński on 28/03/2025.
//

import Foundation

/// Manages user-facing settings and syncs related system state as needed.
final class SettingsManager {
    static let shared = SettingsManager()
    static let defaultOpenAtLogin: Bool = false
    static let defaultDisableModifierKeys: Bool = false
    
    private init() {}

    /// Whether the app should launch at login.
    /// Automatically updates the system login item registration.
    var openAtLogin: Bool {
        get { UserDefaults.openAtLogin }
        set {
            UserDefaults.openAtLogin = newValue
            OpenAtLoginManager.setEnabled(newValue)
        }
    }

    /// Whether modifier keys should be ignored in sound playback.
    var disableModifierKeys: Bool {
        get { UserDefaults.disableModifierKeys }
        set { UserDefaults.disableModifierKeys = newValue }
    }
}

private extension UserDefaults {
    private enum Keys {
        static let openAtLogin = "openAtLogin"
        static let disableModifierKeys = "disableModifierKeys"
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
}
