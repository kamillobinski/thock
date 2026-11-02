import Foundation

final class SettingsEngine {
    static let shared = SettingsEngine()
    
    private init() {}
    
    // MARK: - Open at Login
    
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
    
    // MARK: - Modifier Key Sound
    
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
    
    // MARK: - Cleaning Mode
    
    func isCleaningModeEnabled() -> Bool {
        return SettingsManager.shared.isCleaningMode
    }
    
    @discardableResult
    func toggleCleaningMode() -> Bool {
        let newState = !SettingsManager.shared.isCleaningMode
        SettingsManager.shared.isCleaningMode = newState
        NotificationCenter.default.post(name: .cleaningModeDidChange, object: nil)
        return newState
    }
    
    func setCleaningMode(_ enabled: Bool) {
        SettingsManager.shared.isCleaningMode = enabled
        NotificationCenter.default.post(name: .cleaningModeDidChange, object: nil)
    }
    
    // MARK: - Soundpack Selection
    
    func selectKeyboardSoundpack(_ soundpack: Soundpack) {
        SoundpackEngine.shared.applyKeyboard(soundpack: soundpack)
    }
    
    func selectMouseSoundpack(_ soundpack: Soundpack) {
        SoundpackEngine.shared.applyMouse(soundpack: soundpack)
    }
    
    func refreshMenu() {
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    // MARK: - Rapid Key Events
    
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
    
    // MARK: - Auto Mute on Music Playback
    
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
    
    // MARK: - Idle Timeout
    
    func getIdleTimeoutSeconds() -> TimeInterval {
        return SettingsManager.shared.idleTimeoutSeconds
    }
    
    func setIdleTimeoutSeconds(_ seconds: TimeInterval) {
        SettingsManager.shared.idleTimeoutSeconds = seconds
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    // MARK: - Audio Buffer Size
    
    func getAudioBufferSize() -> UInt32 {
        return SettingsManager.shared.audioBufferSize
    }
    
    func setAudioBufferSize(_ bufferSize: UInt32) {
        SettingsManager.shared.audioBufferSize = bufferSize
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    // MARK: - Selected Audio Device
    
    func getSelectedAudioDeviceUID() -> String? {
        return SettingsManager.shared.selectedAudioDeviceUID
    }
    
    func setSelectedAudioDeviceUID(_ uid: String?) {
        SettingsManager.shared.selectedAudioDeviceUID = uid
        NotificationCenter.default.post(name: .audioDeviceDidChange, object: nil)
    }
    
    // MARK: - Volume

    // The existing per-device volume is the master level used by the menu and CLI.
    
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

    func getKeyboardVolume() -> Float {
        return SettingsManager.shared.keyboardVolume
    }

    func setKeyboardVolume(_ volume: Float) {
        SettingsManager.shared.keyboardVolume = volume
        NotificationCenter.default.post(name: .volumeDidChange, object: nil)
    }

    func getMouseVolume() -> Float {
        return SettingsManager.shared.mouseVolume
    }

    func setMouseVolume(_ volume: Float) {
        SettingsManager.shared.mouseVolume = volume
        NotificationCenter.default.post(name: .volumeDidChange, object: nil)
    }
    
    // MARK: - Pitch Variation
    
    func getPitchVariation() -> Float {
        return SettingsManager.shared.pitchVariation
    }
    
    func setPitchVariation(_ variation: Float) {
        SettingsManager.shared.pitchVariation = variation
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    // MARK: - Mouse Click Sound
    
    func isMouseSoundEnabled() -> Bool {
        return SettingsManager.shared.mouseSoundEnabled
    }
    
    func setMouseSoundEnabled(_ enabled: Bool) {
        SettingsManager.shared.mouseSoundEnabled = enabled
        NotificationCenter.default.post(name: .mouseSoundDidChange, object: nil)
    }
    
    // MARK: - Soft Clipping

    func isSoftClippingEnabled() -> Bool {
        return SettingsManager.shared.softClippingEnabled
    }

    func setSoftClippingEnabled(_ enabled: Bool) {
        SettingsManager.shared.softClippingEnabled = enabled
        NotificationCenter.default.post(name: .softClippingDidChange, object: nil)
    }

    // MARK: - Spatial Audio
    
    func isSpatialAudioEnabled() -> Bool {
        return SettingsManager.shared.spatialAudioEnabled
    }
    
    func setSpatialAudioEnabled(_ enabled: Bool) {
        SettingsManager.shared.spatialAudioEnabled = enabled
        NotificationCenter.default.post(name: .spatialAudioDidChange, object: nil)
    }
    
    func getSpatialWidth() -> Float {
        return SettingsManager.shared.spatialWidth
    }
    
    /// Read on every sound, so no notification is needed.
    func setSpatialWidth(_ width: Float) {
        SettingsManager.shared.spatialWidth = width
    }
    
    // MARK: - Key Overlay
    
    func toggleKeyOverlay() -> Bool {
        let newState = !SettingsManager.shared.keyOverlayEnabled
        setKeyOverlay(newState)
        return newState
    }
    
    func isKeyOverlayEnabled() -> Bool {
        return SettingsManager.shared.keyOverlayEnabled
    }
    
    func setKeyOverlay(_ enabled: Bool) {
        SettingsManager.shared.keyOverlayEnabled = enabled
        applyKeyOverlayVisibility()
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    /// Key overlay display mode: "keyboard" (full floating keyboard) or
    /// "hud" (pressed keys shown briefly at the center of the screen).
    func keyOverlayMode() -> String {
        return SettingsManager.shared.keyOverlayMode
    }

    func setKeyOverlayMode(_ mode: String) {
        SettingsManager.shared.keyOverlayMode = mode
        applyKeyOverlayVisibility()
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    /// Key HUD position: "center", "topLeft", "topRight", "bottomLeft", "bottomRight".
    func keyOverlayHudPosition() -> String {
        return SettingsManager.shared.keyOverlayHudPosition
    }

    func setKeyOverlayHudPosition(_ position: String) {
        SettingsManager.shared.keyOverlayHudPosition = position
        KeyHudManager.shared.refreshPosition()
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    /// Routes the persisted enabled flag to the matching overlay surface:
    /// the full keyboard panel or the center-screen key HUD.
    private func applyKeyOverlayVisibility() {
        let enabled = SettingsManager.shared.keyOverlayEnabled
        let mode = SettingsManager.shared.keyOverlayMode
        KeyOverlayManager.shared.setEnabled(enabled && mode == "keyboard")
        KeyHudManager.shared.setEnabled(enabled && mode == "hud")
    }
    
    func toggleKeyOverlayClickThrough() -> Bool {
        let newState = !SettingsManager.shared.keyOverlayClickThrough
        setKeyOverlayClickThrough(newState)
        return newState
    }
    
    func isKeyOverlayClickThroughEnabled() -> Bool {
        return SettingsManager.shared.keyOverlayClickThrough
    }
    
    func setKeyOverlayClickThrough(_ enabled: Bool) {
        SettingsManager.shared.keyOverlayClickThrough = enabled
        KeyOverlayManager.shared.setClickThrough(enabled)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    // MARK: - Key Overlay Appearance
    
    static let keyOverlayScaleStep: Double = 0.25
    static let keyOverlayScaleRange: ClosedRange<Double> = 0.5...2.0
    static let keyOverlayOpacityStep: Double = 0.1
    static let keyOverlayOpacityRange: ClosedRange<Double> = 0.2...1.0
    
    func keyOverlayScale() -> Double {
        return SettingsManager.shared.keyOverlayScale
    }
    
    func setKeyOverlayScale(_ scale: Double) {
        let clamped = min(max(scale, Self.keyOverlayScaleRange.lowerBound), Self.keyOverlayScaleRange.upperBound)
        SettingsManager.shared.keyOverlayScale = clamped
        KeyOverlayManager.shared.setScale(clamped)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    func increaseKeyOverlayScale() {
        setKeyOverlayScale(keyOverlayScale() + Self.keyOverlayScaleStep)
    }
    
    func decreaseKeyOverlayScale() {
        setKeyOverlayScale(keyOverlayScale() - Self.keyOverlayScaleStep)
    }
    
    func keyOverlayOpacity() -> Double {
        return SettingsManager.shared.keyOverlayOpacity
    }
    
    func setKeyOverlayOpacity(_ opacity: Double) {
        let clamped = min(max(opacity, Self.keyOverlayOpacityRange.lowerBound), Self.keyOverlayOpacityRange.upperBound)
        SettingsManager.shared.keyOverlayOpacity = clamped
        KeyOverlayManager.shared.setOpacity(clamped)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    func increaseKeyOverlayOpacity() {
        setKeyOverlayOpacity(keyOverlayOpacity() + Self.keyOverlayOpacityStep)
    }
    
    func decreaseKeyOverlayOpacity() {
        setKeyOverlayOpacity(keyOverlayOpacity() - Self.keyOverlayOpacityStep)
    }
    
    func isKeyOverlayLightTheme() -> Bool {
        return SettingsManager.shared.keyOverlayTheme == "light"
    }
    
    func toggleKeyOverlayTheme() -> Bool {
        let newTheme = isKeyOverlayLightTheme() ? "dark" : "light"
        SettingsManager.shared.keyOverlayTheme = newTheme
        KeyOverlayManager.shared.setTheme(newTheme)
        KeyHudManager.shared.setTheme(newTheme)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        return newTheme == "light"
    }
    
    func setKeyOverlayLightTheme(_ isLight: Bool) {
        let newTheme = isLight ? "light" : "dark"
        guard SettingsManager.shared.keyOverlayTheme != newTheme else { return }
        SettingsManager.shared.keyOverlayTheme = newTheme
        KeyOverlayManager.shared.setTheme(newTheme)
        KeyHudManager.shared.setTheme(newTheme)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
    
    func resetKeyOverlayPosition() {
        KeyOverlayManager.shared.resetPosition()
    }
    
    // MARK: - Headphone Auto-Enable
    
    func isAutoEnableOnHeadphoneEnabled() -> Bool {
        return SettingsManager.shared.autoEnableOnHeadphone
    }
    
    func setAutoEnableOnHeadphone(_ enabled: Bool) {
        SettingsManager.shared.autoEnableOnHeadphone = enabled
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        
        // When enabling, immediately check headphone state and apply
        if enabled {
            let headphoneConnected = HeadphoneDetector.shared.isHeadphoneConnected()
            AppEngine.shared.setEnabled(headphoneConnected)
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
    static let appStateDidChange = Notification.Name("appStateDidChange")
    static let volumeDidChange = Notification.Name("volumeDidChange")
    static let audioDeviceDidChange = Notification.Name("audioDeviceDidChange")
    static let mouseSoundDidChange = Notification.Name("mouseSoundDidChange")
    static let spatialAudioDidChange = Notification.Name("spatialAudioDidChange")
    static let softClippingDidChange = Notification.Name("softClippingDidChange")
    static let cleaningModeDidChange = Notification.Name("cleaningModeDidChange")
}
