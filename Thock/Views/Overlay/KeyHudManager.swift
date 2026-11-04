import Cocoa
import SwiftUI

/// Owns the center-screen key HUD window ("hud" display mode).
/// The panel is always click-through and shows nothing until a key is pressed.
final class KeyHudManager {
    static let shared = KeyHudManager()

    let model = KeyHudModel()

    private var panel: NSPanel?

    private init() {}

    func applyInitialState() {
        model.theme = SettingsEngine.shared.isKeyOverlayLightTheme() ? "light" : "dark"
        let enabled = SettingsEngine.shared.isKeyOverlayEnabled() && SettingsEngine.shared.keyOverlayMode() == "hud"
        setEnabled(enabled)
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            show()
        } else {
            hide()
        }
    }

    func setTheme(_ theme: String) {
        model.theme = theme
    }

    /// Called from the keyboard event tap (main run loop).
    func handleKeyEvent(keyCode: Int64, isKeyDown: Bool) {
        // Skip updates while hidden (e.g. the other display mode is active).
        guard let panel = panel, panel.isVisible else { return }
        if isKeyDown {
            // Follow the mouse so the HUD appears on the display being used.
            reposition()
            model.keyDown(keyCode)
        } else {
            model.keyUp(keyCode)
        }
    }

    /// Re-apply the persisted HUD position (called when the setting changes).
    func refreshPosition() {
        reposition()
    }

    // MARK: - Window lifecycle

    private func show() {
        if panel == nil {
            panel = makePanel()
        }
        reposition()
        panel?.orderFrontRegardless()
    }

    private func hide() {
        model.reset()
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let size = NSSize(width: 720, height: 140)
        let hosting = NSHostingView(rootView: KeyHudView(model: model))
        hosting.frame = NSRect(origin: .zero, size: size)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        // The HUD is purely a visual indicator; the mouse always passes through.
        panel.ignoresMouseEvents = true
        return panel
    }

    /// Place the HUD on the display that contains the mouse, at the persisted
    /// position: centered, or pinned to one of the four corners.
    private func reposition() {
        guard let panel = panel else { return }
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let margin: CGFloat = 12
        let size = panel.frame.size
        let position = SettingsEngine.shared.keyOverlayHudPosition()
        model.position = position
        let origin: NSPoint
        switch position {
        case "topLeft":
            origin = NSPoint(x: visible.minX + margin, y: visible.maxY - size.height - margin)
        case "topRight":
            origin = NSPoint(x: visible.maxX - size.width - margin, y: visible.maxY - size.height - margin)
        case "bottomLeft":
            origin = NSPoint(x: visible.minX + margin, y: visible.minY + margin)
        case "bottomRight":
            origin = NSPoint(x: visible.maxX - size.width - margin, y: visible.minY + margin)
        default: // "center"
            origin = NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
        }
        panel.setFrameOrigin(origin)
    }
}
