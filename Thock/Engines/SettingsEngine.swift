
import Foundation

final class SettingsEngine {
    static let shared = SettingsEngine()
    
    private init() {}
    
    func toggleOpenAtLogin() -> Bool {
        print("Toggle open at login")
        let newState = !SettingsManager.shared.openAtLogin
        SettingsManager.shared.openAtLogin = newState
        OpenAtLoginManager.setEnabled(newState)
        return newState
    }
    
    func isOpenAtLoginEnabled() -> Bool {
        print("Get open at login state")
        return SettingsManager.shared.openAtLogin
    }
    
    func toggleModifierKeySound() -> Bool {
        print("Toggle sound modifier keys")
        let newState = !SettingsManager.shared.disableModifierKeys
        SettingsManager.shared.disableModifierKeys = newState
        return newState
    }
    
    func isModifierKeySoundDisabled() -> Bool {
        print("Get sound modifier keys state")
        return SettingsManager.shared.disableModifierKeys
    }
    
    func selectMode(mode: Mode) {
        print("Select mode: \(mode)")
        ModeEngine.shared.apply(mode: mode)
    }
    
    func refreshMenu() {
        print("Refresh menu")
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    func toggleIgnoreRapidKeyEvents() -> Bool {
        print("Toggle ignore rapid key events")
        let newState = !SettingsManager.shared.ignoreRapidKeyEvents
        SettingsManager.shared.ignoreRapidKeyEvents = newState
        return newState
    }
    
    func isIgnoreRapidKeyEventsEnabled() -> Bool {
        print("Get ignore rapid key events state")
        return SettingsManager.shared.ignoreRapidKeyEvents
    }

    func toggleAutoMuteOnMusicPlayback() -> Bool {
        print("Toggle auto-mute on music playback")
        let newState = !SettingsManager.shared.autoMuteOnMusicPlayback
        SettingsManager.shared.autoMuteOnMusicPlayback = newState
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        return newState
    }

    func isAutoMuteOnMusicPlaybackEnabled() -> Bool {
        print("Get auto-mute on music playback state")
        return SettingsManager.shared.autoMuteOnMusicPlayback
    }
}

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
    static let appStateDidChange = Notification.Name("appStateDidChange")
}
