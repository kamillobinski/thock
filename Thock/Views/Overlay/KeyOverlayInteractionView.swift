import Cocoa

/// Container view that adds mouse interaction to a borderless panel:
/// - long-press (0.25s) then drag moves the window, even when the SwiftUI
///   content would otherwise swallow the events
/// - for the keyboard panel, a thin edge strip is left unclaimed so the
///   window's own (system) resize handling can take it
final class OverlayInteractionView: NSView {
    /// When true, every mouse event goes to this view instead of the SwiftUI
    /// content (use for content with no interactive controls, e.g. the key
    /// overlay itself). When false, events reach the hosting view and only
    /// the outer grip ring is intercepted for dragging.
    var interceptsAllMouseEvents: Bool = false
    /// Width of the grip ring used in non-intercept mode (control bar).
    var edgeInset: CGFloat = 10
    /// Width of the edge strip left to the window's built-in resize
    /// handling (borderless + resizable panel). 0 disables the strip.
    var edgePassthrough: CGFloat = 0
    /// Whether live window resizes should be mirrored into the overlay
    /// scale factor (keyboard panel only).
    var syncsScaleWithResize: Bool = false
    /// When true, dragging this view moves the keyboard + control bar as
    /// one group (control bar drag handle).
    var movesGroup: Bool = false

    private enum Mode {
        case none, pendingMove, moving
    }

    private var mode: Mode = .none
    private var pressStartScreen: NSPoint = .zero
    private var frameStart: NSRect = .zero
    private var longPressTimer: DispatchWorkItem?

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Hit testing

    override func hitTest(_ point: NSPoint) -> NSView? {
        if interceptsAllMouseEvents {
            let local = convert(point, from: superview)
            guard bounds.contains(local) else { return nil }
            // Leave the edge strip to AppKit's borderless-window resize.
            if edgePassthrough > 0,
               local.x < edgePassthrough || local.x > bounds.width - edgePassthrough
               || local.y < edgePassthrough || local.y > bounds.height - edgePassthrough {
                return nil
            }
            return self
        }
        // Interactive content (control bar): let SwiftUI controls receive
        // clicks, but claim the outer grip ring so the bar can be dragged
        // by its edges even if the hosting view swallows events.
        if let hit = super.hitTest(point) {
            let local = convert(point, from: superview)
            if bounds.contains(local), isInGripRing(local) {
                return self
            }
            return hit
        }
        return nil
    }

    private func isInGripRing(_ location: NSPoint) -> Bool {
        location.x < edgeInset || location.x > bounds.width - edgeInset
            || location.y < edgeInset || location.y > bounds.height - edgeInset
    }

    // MARK: - Long-press drag

    override func mouseDown(with event: NSEvent) {
        pressStartScreen = NSEvent.mouseLocation
        frameStart = window?.frame ?? .zero
        KeyOverlayManager.shared.noteControlBarInteraction()
        if movesGroup {
            KeyOverlayManager.shared.beginGroupMove()
        }

        mode = .pendingMove
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.mode == .pendingMove else { return }
            self.mode = .moving
        }
        longPressTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    override func mouseDragged(with event: NSEvent) {
        guard mode == .moving else { return }
        KeyOverlayManager.shared.noteControlBarInteraction()
        let location = NSEvent.mouseLocation
        let dx = location.x - pressStartScreen.x
        let dy = location.y - pressStartScreen.y
        if movesGroup {
            // Dragging the control bar moves keyboard + bar as one group.
            KeyOverlayManager.shared.updateGroupMove(dx: dx, dy: dy)
        } else {
            window?.setFrameOrigin(NSPoint(
                x: frameStart.minX + dx,
                y: frameStart.minY + dy
            ))
            KeyOverlayManager.shared.noteKeyboardFrameChanged()
        }
    }

    override func mouseUp(with event: NSEvent) {
        longPressTimer?.cancel()
        longPressTimer = nil
        mode = .none
        if movesGroup {
            KeyOverlayManager.shared.endGroupMove()
        }
    }

    // MARK: - Scale sync with system resize

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard syncsScaleWithResize, window != nil, newSize.width > 0 else { return }
        KeyOverlayManager.shared.noteLiveResize(width: newSize.width)
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        guard syncsScaleWithResize else { return }
        KeyOverlayManager.shared.endLiveResize()
    }
}
