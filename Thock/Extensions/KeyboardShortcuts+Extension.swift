import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleThock = Self("toggleThock")
    static let toggleCleaningMode = Self("toggleCleaningMode")
    static let toggleKeyOverlay = Self("toggleKeyOverlay", default: .init(.k, modifiers: [.control, .option]))
    static let toggleKeyOverlayControls = Self("toggleKeyOverlayControls", default: .init(.l, modifiers: [.control, .option]))
}
