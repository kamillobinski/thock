import Carbon.HIToolbox
import Foundation

/// Physical key positions on a Mac keyboard, used to place key sounds in space.
/// Keycodes are physical, so this is independent of the active input layout.
enum KeyLayout {
    enum Physical {
        case ansi, iso, jis

        /// Resolve the event's keyboard type on the main event-tap thread before playback is
        /// dispatched. KBGetLayoutType is not thread safe; never consult global keyboard state.
        static func fromKeyboardType(_ keyboardType: Int64) -> Physical {
            precondition(Thread.isMainThread, "Capture the physical keyboard layout on the main thread")
            guard keyboardType >= 0, let type = Int16(exactly: keyboardType) else { return .ansi }
            switch Int(KBGetLayoutType(type)) {
            case kKeyboardISO: return .iso
            case kKeyboardJIS: return .jis
            default: return .ansi
            }
        }
    }

    /// Main block width in key units (Esc/` left edge to Delete/Return right edge)
    static let width: Float = 15

    private static let unknown: (x: Float, row: Float) = (7.5, 3)

    // keyCode: (horizontal key center in units, row 0 = F-row … 5 = space row)
    private static let keys: [Int64: (x: Float, row: Float)] = [
        // F-ROW
        53: (0.5, 0), 122: (2.5, 0), 120: (3.5, 0), 99: (4.5, 0), 118: (5.5, 0),
        96: (7.0, 0), 97: (8.0, 0), 98: (9.0, 0), 100: (10.0, 0),
        101: (11.5, 0), 109: (12.5, 0), 103: (13.5, 0), 111: (14.5, 0),
        105: (15, 0), 107: (15, 0), 113: (15, 0), 106: (15, 0), 64: (15, 0), 79: (15, 0), 80: (15, 0), 90: (15, 0),

        // NUMBER ROW (93 is the JIS yen key)
        50: (0.5, 1), 18: (1.5, 1), 19: (2.5, 1), 20: (3.5, 1), 21: (4.5, 1), 23: (5.5, 1),
        22: (6.5, 1), 26: (7.5, 1), 28: (8.5, 1), 25: (9.5, 1), 29: (10.5, 1),
        27: (11.5, 1), 24: (12.5, 1), 93: (13.5, 1), 51: (14.0, 1),

        // TAB ROW
        48: (0.75, 2), 12: (2.0, 2), 13: (3.0, 2), 14: (4.0, 2), 15: (5.0, 2), 17: (6.0, 2),
        16: (7.0, 2), 32: (8.0, 2), 34: (9.0, 2), 31: (10.0, 2), 35: (11.0, 2),
        33: (12.0, 2), 30: (13.0, 2), 42: (14.25, 2),

        // CAPS ROW
        57: (0.875, 3), 0: (2.25, 3), 1: (3.25, 3), 2: (4.25, 3), 3: (5.25, 3), 5: (6.25, 3),
        4: (7.25, 3), 38: (8.25, 3), 40: (9.25, 3), 37: (10.25, 3), 41: (11.25, 3),
        39: (12.25, 3), 36: (13.875, 3),

        // SHIFT ROW (94 is the JIS underscore key)
        56: (1.125, 4), 6: (2.75, 4), 7: (3.75, 4), 8: (4.75, 4), 9: (5.75, 4),
        11: (6.75, 4), 45: (7.75, 4), 46: (8.75, 4), 43: (9.75, 4), 47: (10.75, 4),
        44: (11.75, 4), 94: (12.75, 4), 60: (13.875, 4),

        // BOTTOM ROW (laptop arrows, 102/104 are the JIS eisu/kana keys)
        63: (0.5, 5), 59: (1.5, 5), 58: (2.5, 5), 55: (3.75, 5), 102: (5.25, 5), 49: (7.5, 5), 104: (9.75, 5),
        54: (10.25, 5), 61: (11.25, 5), 62: (11.75, 5),
        123: (12.5, 5), 125: (13.5, 5), 126: (13.5, 5), 124: (14.5, 5),

        // NAV CLUSTER
        114: (15, 1), 115: (15, 1), 116: (15, 1), 117: (15, 2), 119: (15, 2), 121: (15, 2),

        // NUMPAD
        71: (15, 1), 81: (15, 1), 75: (15, 1), 67: (15, 1),
        89: (15, 2), 91: (15, 2), 92: (15, 2), 78: (15, 2),
        86: (15, 3), 87: (15, 3), 88: (15, 3), 69: (15, 3),
        83: (15, 4), 84: (15, 4), 85: (15, 4), 76: (15, 4),
        82: (15, 5), 65: (15, 5),
    ]

    /// ISO keyboards move the grave key (50) next to left shift, put § (10) top left and
    /// the backslash/hash key (42) left of the tall Return
    private static let isoKeys: [Int64: (x: Float, row: Float)] = [
        10: (0.5, 1), 50: (1.75, 4), 42: (13.25, 3),
    ]

    static func position(for keyCode: Int64, width spread: Float = SpatialMath.defaultWidth,
                         layout: Physical = .ansi) -> SoundPosition {
        let key = (layout == .iso ? isoKeys[keyCode] : nil) ?? keys[keyCode] ?? unknown
        let x = min(max(key.x, 0), width)
        return SoundPosition(
            azimuth: (x / width - 0.5) * 2 * spread,
            elevation: -10 - key.row / 5 * 10
        )
    }
}
