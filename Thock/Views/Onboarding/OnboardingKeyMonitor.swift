import AppKit
import IOKit.hidsystem

@available(macOS 14.0, *)
@MainActor
final class OnboardingKeyMonitor {
    static let shared = OnboardingKeyMonitor()

    private var monitor: Any?
    private var holders = 0

    private init() {}

    func acquire() {
        holders += 1
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            MainActor.assumeIsolated { OnboardingKeyMonitor.shared.handle(event) }
        }
    }

    func release() {
        holders = max(0, holders - 1)
        guard holders == 0, let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        OnboardingKeyboardModel.shared.releaseAll()
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard OnboardingWindowController.shared.isOnboardingWindow(event.window) else { return event }
        let keyboard = OnboardingKeyboardModel.shared
        let audio = OnboardingAudio.shared
        let code = Int64(event.keyCode)
        let layout = KeyLayout.Physical.fromKeyboardType(event.cgEvent?.getIntegerValueField(.keyboardEventKeyboardType) ?? -1)

        switch event.type {
        case .flagsChanged where code == 57:
            keyboard.press(code, byUser: true)
            audio.playKey(code, down: true, synthetic: false, layout: layout)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                keyboard.release(code)
                audio.playKey(code, down: false, synthetic: false, layout: layout)
            }
            return event

        case .flagsChanged:
            guard let down = Self.modifierIsDown(code, flags: event.modifierFlags) else { return event }
            if down { keyboard.press(code, byUser: true) } else { keyboard.release(code) }
            if !SettingsEngine.shared.isModifierKeySoundDisabled() {
                audio.playKey(code, down: down, synthetic: false, layout: layout)
            }
            return event

        case .keyDown:
            if event.modifierFlags.contains(.command) { return event }
            let passes = Self.passThroughKeys.contains(code)
            guard !event.isARepeat else { return passes ? event : nil }
            keyboard.press(code, legend: OnboardingKeyboardModel.legend(for: code, characters: event.charactersIgnoringModifiers), byUser: true)
            audio.playKey(code, down: true, synthetic: false, layout: layout)
            return passes ? event : nil

        case .keyUp:
            guard keyboard.pressedKeys.contains(code) else { return event }
            keyboard.release(code)
            audio.playKey(code, down: false, synthetic: false, layout: layout)
            return Self.passThroughKeys.contains(code) ? event : nil

        default:
            return event
        }
    }

    private static let passThroughKeys: Set<Int64> = [36, 76, 53, 48, 125, 126]

    private static func modifierIsDown(_ code: Int64, flags: NSEvent.ModifierFlags) -> Bool? {
        let mask: UInt
        switch code {
        case 54: mask = UInt(NX_DEVICERCMDKEYMASK)
        case 55: mask = UInt(NX_DEVICELCMDKEYMASK)
        case 56: mask = UInt(NX_DEVICELSHIFTKEYMASK)
        case 57: mask = NSEvent.ModifierFlags.capsLock.rawValue
        case 58: mask = UInt(NX_DEVICELALTKEYMASK)
        case 59: mask = UInt(NX_DEVICELCTLKEYMASK)
        case 60: mask = UInt(NX_DEVICERSHIFTKEYMASK)
        case 61: mask = UInt(NX_DEVICERALTKEYMASK)
        case 62: mask = UInt(NX_DEVICERCTLKEYMASK)
        case 63: mask = NSEvent.ModifierFlags.function.rawValue
        default: return nil
        }
        return flags.rawValue & mask != 0
    }
}
