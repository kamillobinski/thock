import Cocoa
import SwiftUI

/// Owns the floating key overlay window and feeds it key events.
final class KeyOverlayManager {
    static let shared = KeyOverlayManager()

    let model = KeyOverlayModel()

    private var panel: NSPanel?
    private var controlPanel: NSPanel?
    private var controlBarHideTimer: DispatchWorkItem?
    /// Seconds of inactivity before the control bar auto-hides.
    private let controlBarAutoHideDelay: TimeInterval = 6
    /// Global monitors active while the control bar is visible (Esc / click-outside to dismiss).
    private var controlBarEventMonitors: [Any] = []
    /// Keyboard frame captured when a control-bar drag starts, so the whole
    /// group (keyboard + bar) can move together.
    private var groupMoveBaseFrame: NSRect?

    private init() {}

    /// Show or hide the overlay according to the persisted setting.
    func applyInitialState() {
        // Only surface the full keyboard in "keyboard" display mode;
        // "hud" mode is handled by KeyHudManager.
        let enabled = SettingsEngine.shared.isKeyOverlayEnabled() && SettingsEngine.shared.keyOverlayMode() == "keyboard"
        model.scale = SettingsEngine.shared.keyOverlayScale()
        model.theme = SettingsEngine.shared.isKeyOverlayLightTheme() ? "light" : "dark"
        model.opacity = SettingsEngine.shared.keyOverlayOpacity()
        setEnabled(enabled)
        setClickThrough(SettingsEngine.shared.isKeyOverlayClickThroughEnabled())
        setOpacity(SettingsEngine.shared.keyOverlayOpacity())
    }
    
    func setEnabled(_ enabled: Bool) {
        if enabled {
            show()
        } else {
            hide()
        }
    }
    
    func setClickThrough(_ enabled: Bool) {
        panel?.ignoresMouseEvents = enabled
    }
    
    // MARK: - Appearance
    
    /// Content size at scale 1.0 (15u wide rows, unit 26, spacing 4, padding 8).
    static let baseSize = NSSize(width: 15 * 26 + 14 * 4 + 16, height: 5 * 26 + 4 * 4 + 16)
    
    func setScale(_ scale: Double) {
        model.scale = scale
        guard let panel = panel else { return }
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        panel.setContentSize(NSSize(width: Self.baseSize.width * scale, height: Self.baseSize.height * scale))
        panel.setFrameOrigin(NSPoint(x: center.x - panel.frame.width / 2, y: center.y - panel.frame.height / 2))
        syncControlBarAttachment()
    }
    
    /// Live-resize callback from the interaction view while the user
    /// edge-resizes the panel: rescale the content to fit the new width.
    func noteLiveResize(width: CGFloat) {
        let scale = Double(width / Self.baseSize.width)
        if abs(scale - model.scale) > 0.001 {
            model.scale = scale
        }
        syncControlBarAttachment()
    }

    /// Persist the scale once the user finishes an edge-resize drag.
    func endLiveResize() {
        SettingsManager.shared.keyOverlayScale = model.scale
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    func setOpacity(_ opacity: Double) {
        model.opacity = opacity
        panel?.alphaValue = CGFloat(opacity)
    }
    
    func setTheme(_ theme: String) {
        model.theme = theme
    }
    
    func resetPosition() {
        guard let panel = panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: visible.midX - panel.frame.width / 2,
            y: visible.minY + 48
        ))
        syncControlBarAttachment()
    }

    // MARK: - Attachment (control bar follows the keyboard)

    /// Keyboard frame changed (drag, resize, reset): keep the control bar attached.
    func noteKeyboardFrameChanged() {
        syncControlBarAttachment()
    }

    /// Group drag started from the control bar: dragging the bar moves
    /// keyboard + bar as one unit.
    func beginGroupMove() {
        groupMoveBaseFrame = panel?.frame
    }

    func updateGroupMove(dx: CGFloat, dy: CGFloat) {
        guard let panel = panel, let base = groupMoveBaseFrame else { return }
        panel.setFrameOrigin(NSPoint(x: base.minX + dx, y: base.minY + dy))
        syncControlBarAttachment()
    }

    func endGroupMove() {
        groupMoveBaseFrame = nil
    }
    
    // MARK: - Control bar
    
    /// ⌃⌥L handler: toggle the control bar above the overlay.
    func toggleControlBar() {
        if controlPanel?.isVisible == true {
            hideControlBar()
        } else {
            showControlBar()
        }
    }
    
    func showControlBar() {
        // ⌃⌥L in "hud" display mode first switches to the full keyboard,
        // since the control bar only makes sense with the keyboard visible.
        if SettingsEngine.shared.keyOverlayMode() == "hud" {
            SettingsEngine.shared.setKeyOverlayMode("keyboard")
        }
        // Control bar only makes sense with the keyboard visible.
        if panel == nil || panel?.isVisible == false {
            SettingsEngine.shared.setKeyOverlay(true)
        }
        guard let panel = panel else { return }
        if controlPanel == nil {
            controlPanel = makeControlPanel()
        }
        guard let controlPanel = controlPanel else { return }
        syncControlBarAttachment()
        controlPanel.orderFrontRegardless()
        // While the control bar is up, lift click-through so the keyboard
        // itself can be dragged around.
        panel.ignoresMouseEvents = false
        installControlBarEventMonitors()
        scheduleControlBarAutoHide()
    }
    
    func hideControlBar() {
        controlBarHideTimer?.cancel()
        controlBarHideTimer = nil
        removeControlBarEventMonitors()
        controlPanel?.orderOut(nil)
        panel?.ignoresMouseEvents = SettingsEngine.shared.isKeyOverlayClickThroughEnabled()
    }
    
    /// Esc or a click anywhere outside the overlay/control bar dismisses the control bar.
    private func installControlBarEventMonitors() {
        removeControlBarEventMonitors()
        
        if let keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if event.keyCode == 53 { // Esc
                DispatchQueue.main.async { self?.hideControlBar() }
            }
        }) {
            controlBarEventMonitors.append(keyMonitor)
        }
        
        if let clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            guard let self = self else { return }
            if event.windowNumber == self.panel?.windowNumber || event.windowNumber == self.controlPanel?.windowNumber {
                return
            }
            DispatchQueue.main.async { self.hideControlBar() }
        }) {
            controlBarEventMonitors.append(clickMonitor)
        }
    }
    
    private func removeControlBarEventMonitors() {
        controlBarEventMonitors.forEach { NSEvent.removeMonitor($0) }
        controlBarEventMonitors.removeAll()
    }
    
    /// Called by control bar controls on every interaction.
    func noteControlBarInteraction() {
        scheduleControlBarAutoHide()
    }
    
    private func scheduleControlBarAutoHide() {
        controlBarHideTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.hideControlBar()
        }
        controlBarHideTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + controlBarAutoHideDelay, execute: work)
    }
    
    /// Place the control bar attached to the keyboard: horizontally centered,
    /// 12pt above its top edge — or below when there is no room above
    /// (e.g. keyboard parked against the top of the screen). Clamped to the
    /// visible frame of the screen the keyboard is currently on.
    /// Also runs before the bar is ordered front (while still hidden), so a
    /// freshly shown bar is always positioned relative to the *current*
    /// keyboard frame instead of a stale or default origin.
    private func syncControlBarAttachment() {
        guard let panel = panel, let controlPanel = controlPanel else { return }
        let barSize = controlPanel.frame.size
        let gap: CGFloat = 12
        let screen = screenContaining(panel.frame) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? panel.frame
        let aboveY = panel.frame.maxY + gap
        let belowY = panel.frame.minY - gap - barSize.height
        let showBelow = aboveY + barSize.height > visible.maxY - 8 && belowY >= visible.minY + 8
        var origin = NSPoint(
            x: panel.frame.midX - barSize.width / 2,
            y: showBelow ? belowY : aboveY
        )
        origin.x = max(visible.minX + 8, min(origin.x, visible.maxX - barSize.width - 8))
        origin.y = max(visible.minY + 8, min(origin.y, visible.maxY - barSize.height - 8))
        controlPanel.setFrameOrigin(origin)
    }

    private func screenContaining(_ frame: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.visibleFrame.intersects(frame) }
    }
    
    private func makeControlPanel() -> NSPanel {
        let hosting = NSHostingView(rootView: KeyOverlayControlBarView())
        let size = NSSize(width: 470, height: 44)
        let container = OverlayInteractionView(frame: NSRect(origin: .zero, size: size))
        container.interceptsAllMouseEvents = false
        container.movesGroup = true
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)
        
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = container
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        return panel
    }

    /// Called from the keyboard event tap (main run loop).
    func handleKeyEvent(keyCode: Int64, isKeyDown: Bool) {
        guard panel != nil else { return }
        if isKeyDown {
            model.keyDown(keyCode)
        } else {
            model.keyUp(keyCode)
        }
    }

    // MARK: - Window lifecycle

    private func show() {
        if panel == nil {
            panel = makePanel()
        }
        panel?.orderFrontRegardless()
    }

    private func hide() {
        model.reset()
        hideControlBar()
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        model.scale = SettingsEngine.shared.keyOverlayScale()
        model.theme = SettingsEngine.shared.isKeyOverlayLightTheme() ? "light" : "dark"
        let hosting = NSHostingView(rootView: KeyOverlayView(model: model))
        let scale = model.scale
        let size = NSSize(width: Self.baseSize.width * scale, height: Self.baseSize.height * scale)
        let container = OverlayInteractionView(frame: NSRect(origin: .zero, size: size))
        container.interceptsAllMouseEvents = true
        container.edgePassthrough = 6
        container.syncsScaleWithResize = true
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.contentView = container
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        // Dragging is handled manually by OverlayInteractionView (long-press).
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = SettingsEngine.shared.isKeyOverlayClickThroughEnabled()
        panel.alphaValue = CGFloat(SettingsEngine.shared.keyOverlayOpacity())
        // System-managed edge/corner resize with Finder-style anchoring,
        // aspect-locked to the keyboard and clamped to the scale range.
        panel.contentAspectRatio = Self.baseSize
        let minScale = SettingsEngine.keyOverlayScaleRange.lowerBound
        let maxScale = SettingsEngine.keyOverlayScaleRange.upperBound
        panel.contentMinSize = NSSize(width: Self.baseSize.width * minScale, height: Self.baseSize.height * minScale)
        panel.contentMaxSize = NSSize(width: Self.baseSize.width * maxScale, height: Self.baseSize.height * maxScale)
        panel.setFrameAutosaveName("KeyOverlayPanelV2")

        // First launch: park at the bottom center of the main screen.
        if panel.frame.origin == .zero, let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let origin = NSPoint(
                x: visible.midX - panel.frame.width / 2,
                y: visible.minY + 48
            )
            panel.setFrameOrigin(origin)
        }

        return panel
    }
}
