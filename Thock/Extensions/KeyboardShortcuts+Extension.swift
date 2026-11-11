import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleThock = Self("toggleThock")
    static let toggleCleaningMode = Self("toggleCleaningMode")
    // No default shortcuts: users assign their own in Settings → Shortcuts,
    // matching the rest of the features (e.g. cleaning mode).
    static let toggleKeyOverlay = Self("toggleKeyOverlay")
    static let toggleKeyOverlayControls = Self("toggleKeyOverlayControls")
    static let nextKeyboardSoundpack = Self("nextKeyboardSoundpack")
    static let previousKeyboardSoundpack = Self("previousKeyboardSoundpack")
}
