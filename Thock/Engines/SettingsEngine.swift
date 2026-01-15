import Foundation

final class SettingsEngine {
    static let shared = SettingsEngine()
    
    private init() {}
    
    func toggleOpenAtLogin() -> Bool {
        let newState = !SettingsManager.shared.openAtLogin
        SettingsManager.shared.openAtLogin = newState
        OpenAtLoginManager.setEnabled(newState)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        return newState
    }
    
    func isOpenAtLoginEnabled() -> Bool {
        return SettingsManager.shared.openAtLogin
    }
    
    func setOpenAtLogin(_ enabled: Bool) {
        SettingsManager.shared.openAtLogin = enabled
        OpenAtLoginManager.setEnabled(enabled)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    func toggleModifierKeySound() -> Bool {
        let newState = !SettingsManager.shared.disableModifierKeys
        SettingsManager.shared.disableModifierKeys = newState
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        return newState
    }
    
    func isModifierKeySoundDisabled() -> Bool {
        return SettingsManager.shared.disableModifierKeys
    }
    
    func setModifierKeySound(_ disabled: Bool) {
        SettingsManager.shared.disableModifierKeys = disabled
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    func selectMode(mode: Mode) {
        ModeEngine.shared.apply(mode: mode)
    }
    
    func refreshMenu() {
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    func toggleIgnoreRapidKeyEvents() -> Bool {
        let newState = !SettingsManager.shared.ignoreRapidKeyEvents
        SettingsManager.shared.ignoreRapidKeyEvents = newState
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        return newState
    }
    
    func isIgnoreRapidKeyEventsEnabled() -> Bool {
        return SettingsManager.shared.ignoreRapidKeyEvents
    }
    
    func setIgnoreRapidKeyEvents(_ enabled: Bool) {
        SettingsManager.shared.ignoreRapidKeyEvents = enabled
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    func toggleAutoMuteOnMusicPlayback() -> Bool {
        let newState = !SettingsManager.shared.autoMuteOnMusicPlayback
        SettingsManager.shared.autoMuteOnMusicPlayback = newState
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        return newState
    }
    
    func isAutoMuteOnMusicPlaybackEnabled() -> Bool {
        return SettingsManager.shared.autoMuteOnMusicPlayback
    }
    
    func setAutoMuteOnMusicPlayback(_ enabled: Bool) {
        SettingsManager.shared.autoMuteOnMusicPlayback = enabled
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    func getIdleTimeoutSeconds() -> TimeInterval {
        return SettingsManager.shared.idleTimeoutSeconds
    }
    
    func setIdleTimeoutSeconds(_ seconds: TimeInterval) {
        SettingsManager.shared.idleTimeoutSeconds = seconds
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    func getAudioBufferSize() -> UInt32 {
        return SettingsManager.shared.audioBufferSize
    }
    
    func setAudioBufferSize(_ bufferSize: UInt32) {
        SettingsManager.shared.audioBufferSize = bufferSize
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    func getSelectedAudioDeviceUID() -> String? {
        return SettingsManager.shared.selectedAudioDeviceUID
    }
    
    func setSelectedAudioDeviceUID(_ uid: String?) {
        SettingsManager.shared.selectedAudioDeviceUID = uid
        NotificationCenter.default.post(name: .audioDeviceDidChange, object: nil)
    }
    
    func getVolume(for deviceUID: String) -> Float {
        let perDeviceVolumes = SettingsManager.shared.perDeviceVolumes
        return perDeviceVolumes[deviceUID] ?? 0.5
    }
    
    func setVolume(_ volume: Float, for deviceUID: String) {
        let clampedVolume = max(0.0, min(1.0, volume))
        var perDeviceVolumes = SettingsManager.shared.perDeviceVolumes
        perDeviceVolumes[deviceUID] = clampedVolume
        SettingsManager.shared.perDeviceVolumes = perDeviceVolumes
        NotificationCenter.default.post(name: .volumeDidChange, object: nil)
    }
    
    func getVolume() -> Float {
        let deviceUID = SoundManager.shared.getCurrentOutputDeviceUID()
        return getVolume(for: deviceUID)
    }
    
    func setVolume(_ volume: Float) {
        let deviceUID = SoundManager.shared.getCurrentOutputDeviceUID()
        setVolume(volume, for: deviceUID)
    }
    
    func getPitchVariation() -> Float {
        return SettingsManager.shared.pitchVariation
    }
    
    func setPitchVariation(_ variation: Float) {
        SettingsManager.shared.pitchVariation = variation
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    // MARK: - Trackpad Sound
    
    func isTrackpadSoundEnabled() -> Bool {
        return SettingsManager.shared.trackpadSoundEnabled
    }
    
    func setTrackpadSoundEnabled(_ enabled: Bool) {
        SettingsManager.shared.trackpadSoundEnabled = enabled
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
}

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
    static let appStateDidChange = Notification.Name("appStateDidChange")
    static let volumeDidChange = Notification.Name("volumeDidChange")
    static let audioDeviceDidChange = Notification.Name("audioDeviceDidChange")
}
