import AppKit
import SwiftUI

extension Notification.Name {
    static let keyboardTrackingDidStart = Notification.Name("keyboardTrackingDidStart")
}

@available(macOS 14.0, *)
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()

    private static let completedKey = "hasCompletedOnboarding"
    private static let forceKey = "forceOnboarding"

    private var window: NSWindow?
    private var recoveryWindow: NSWindow?
    weak var statusItemButton: NSStatusBarButton?

    var shouldShowOnLaunch: Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: Self.forceKey) || !defaults.bool(forKey: Self.completedKey)
    }

    func isOnboardingWindow(_ candidate: NSWindow?) -> Bool {
        candidate != nil && candidate === window
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        OnboardingAudio.shared.prepare()

        let root = OnboardingView(onFinish: { [weak self] in self?.finish() })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: OnboardingMetrics.windowSize.width, height: OnboardingMetrics.windowSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.backgroundColor = .windowBackgroundColor
        window.contentView = NSHostingView(rootView: root)
        window.setFrame(NSRect(origin: .zero, size: OnboardingMetrics.windowSize), display: false)
        window.center()

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showPermissionRecovery(takeFocus: Bool) {
        guard window == nil else { return }
        if let recoveryWindow {
            present(recoveryWindow, takeFocus: takeFocus)
            return
        }

        let root = PermissionRecoveryView(onClose: { [weak self] in self?.recoveryWindow?.close() })
        let size = PermissionRecoveryView.windowSize
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.backgroundColor = .windowBackgroundColor
        window.contentView = NSHostingView(rootView: root)
        window.setFrame(NSRect(origin: .zero, size: size), display: false)
        window.center()

        recoveryWindow = window
        present(window, takeFocus: takeFocus)
    }

    private func present(_ window: NSWindow, takeFocus: Bool) {
        if takeFocus {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            window.orderFrontRegardless()
        }
    }

    func highlightStatusItem() {
        guard let button = statusItemButton else { return }
        let original = button.alphaValue
        var pulses = 0
        Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { timer in
            pulses += 1
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                button.animator().alphaValue = pulses.isMultiple(of: 2) ? original : 0.15
            }
            if pulses >= 6 {
                timer.invalidate()
                button.alphaValue = original
            }
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        UserDefaults.standard.removeObject(forKey: Self.forceKey)
        window?.close()
        highlightStatusItem()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        if closing === window { window = nil }
        if closing === recoveryWindow { recoveryWindow = nil }
    }
}
