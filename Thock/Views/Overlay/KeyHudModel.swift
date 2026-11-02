import Foundation

/// State for the center-screen key HUD display mode.
///
/// Behavior:
/// - Pressing a key shows it immediately; rapid successive presses replace
///   the previous combo right away.
/// - Keys held together are shown together (e.g. ⌘ + C).
/// - Once every pressed key is released, the last combo lingers for a
///   short moment, then the HUD fades out.
final class KeyHudModel: ObservableObject {
    /// How long the last combo stays on screen after all keys are released.
    static let lingerDuration: TimeInterval = 1.0

    /// Keys currently shown, in press order.
    @Published private(set) var displayKeys: [Int64] = []
    /// Whether the HUD is visible (fades via animation in the view).
    @Published private(set) var visible = false
    @Published var theme: String = "dark"

    /// Keys physically held right now, in press order.
    private var pressedOrder: [Int64] = []
    private var lingerTimer: DispatchWorkItem?

    func keyDown(_ keyCode: Int64) {
        lingerTimer?.cancel()
        lingerTimer = nil
        if !pressedOrder.contains(keyCode) {
            pressedOrder.append(keyCode)
        }
        // The display always mirrors the currently-held combo: rapid taps
        // replace the previous key, ⌘+V replaces ⌘+C, etc.
        displayKeys = pressedOrder
        visible = true
    }

    func keyUp(_ keyCode: Int64) {
        pressedOrder.removeAll { $0 == keyCode }
        // Keep the last combo on screen briefly once nothing is held.
        if pressedOrder.isEmpty, visible {
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.visible = false
                self.lingerTimer = nil
            }
            lingerTimer = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.lingerDuration, execute: work)
        }
    }

    func reset() {
        lingerTimer?.cancel()
        lingerTimer = nil
        pressedOrder.removeAll()
        displayKeys = []
        visible = false
    }
}

/// Human-readable glyphs for physical key codes (layout-independent).
enum KeyHudGlyphs {
    private static let letters: [Int64: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 50: "`",
    ]

    static func label(for keyCode: Int64) -> String {
        switch keyCode {
        case 53: return "esc"
        case 48: return "⇥"
        case 49: return "␣"
        case 51: return "⌫"
        case 54, 55: return "⌘"
        case 56, 60: return "⇧"
        case 57: return "⇪"
        case 58, 61: return "⌥"
        case 59, 62: return "⌃"
        case 63: return "fn"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return letters[keyCode] ?? ""
        }
    }
}
