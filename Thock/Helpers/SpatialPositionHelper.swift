//
//  SpatialPositionHelper.swift
//  Thock
//
//  Created on 23/08/2026.
//

import Foundation

/// Helper for spatial audio positioning and stereo panning calculations.
struct SpatialPositionHelper {
    
    struct StereoGains {
        let left: Float
        let right: Float
    }
    
    /// Maps macOS hardware key codes to horizontal stereo pan positions from -1.0 (far left) to +1.0 (far right).
    private static let keyPositionMap: [Int64: Float] = [
        // ESC / FUNCTION ROW
        53: -0.85,  // esc
        122: -0.75, // f1
        120: -0.62, // f2
        99:  -0.49, // f3
        118: -0.36, // f4
        96:  -0.18, // f5
        97:  -0.05, // f6
        98:   0.08, // f7
        100:  0.21, // f8
        101:  0.39, // f9
        109:  0.52, // f10
        103:  0.65, // f11
        111:  0.78, // f12
        
        // NUMBER ROW
        50: -0.85,  // `
        18: -0.72,  // 1
        19: -0.59,  // 2
        20: -0.46,  // 3
        21: -0.33,  // 4
        23: -0.20,  // 5
        22: -0.07,  // 6
        26:  0.06,  // 7
        28:  0.19,  // 8
        25:  0.32,  // 9
        29:  0.45,  // 0
        27:  0.58,  // -
        24:  0.71,  // =
        51:  0.84,  // delete / backspace
        
        // TAB / QWERTY ROW
        48: -0.85,  // tab
        12: -0.68,  // q
        13: -0.55,  // w
        14: -0.42,  // e
        15: -0.29,  // r
        17: -0.16,  // t
        16: -0.03,  // y
        32:  0.10,  // u
        34:  0.23,  // i
        31:  0.36,  // o
        35:  0.49,  // p
        33:  0.62,  // [
        30:  0.75,  // ]
        42:  0.85,  // \
        
        // CAPS LOCK / HOME ROW
        57: -0.85,  // capsLock
        0:  -0.65,  // a
        1:  -0.52,  // s
        2:  -0.39,  // d
        3:  -0.26,  // f
        5:  -0.13,  // g
        4:   0.00,  // h
        38:  0.13,  // j
        40:  0.26,  // k
        37:  0.39,  // l
        41:  0.52,  // ;
        39:  0.65,  // '
        36:  0.82,  // enter
        76:  0.82,  // numpad enter / enter
        
        // SHIFT / BOTTOM ROW
        56: -0.85,  // shiftLeft
        6:  -0.60,  // z
        7:  -0.47,  // x
        8:  -0.34,  // c
        9:  -0.21,  // v
        11: -0.08,  // b
        45:  0.05,  // n
        46:  0.18,  // m
        43:  0.31,  // ,
        47:  0.44,  // .
        44:  0.57,  // /
        60:  0.80,  // shiftRight
        
        // MODIFIERS / SPACE ROW
        59: -0.85,  // ctrlLeft
        63: -0.80,  // fn
        58: -0.70,  // optionLeft
        54: -0.55,  // commandLeft
        49:  0.00,  // space (center)
        55:  0.55,  // commandRight
        61:  0.70,  // optionRight
        
        // NAVIGATION KEYS
        115: 0.88,  // home
        116: 0.92,  // pgUp
        121: 0.92,  // pgDn
        119: 0.88,  // end
        123: 0.82,  // arrLeft
        126: 0.86,  // arrUp
        125: 0.86,  // arrDown
        124: 0.90,  // arrRight
        
        // NUMPAD
        71: 0.94,   // clear
        81: 0.96,   // =
        75: 0.96,   // /
        67: 0.98,   // *
        89: 0.94,   // 7
        91: 0.96,   // 8
        92: 0.98,   // 9
        78: 0.99,   // -
        86: 0.94,   // 4
        87: 0.96,   // 5
        88: 0.98,   // 6
        69: 0.99,   // +
        83: 0.94,   // 1
        84: 0.96,   // 2
        85: 0.98,   // 3
        82: 0.94,   // 0
        65: 0.97    // .
    ]
    
    /// Returns the normalized horizontal pan (-1.0 to 1.0) for a given keyboard key code.
    static func panForKeyCode(_ keyCode: Int64) -> Float {
        return keyPositionMap[keyCode] ?? 0.0
    }
    
    /// Calculates left and right channel gains using the constant-power panning law.
    /// - Parameters:
    ///   - pan: Horizontal position from -1.0 (full left) to +1.0 (full right).
    ///   - spread: Spatial spread intensity from 0.0 (mono/centered) to 1.0 (full width).
    /// - Returns: StereoGains with left and right multipliers.
    static func calculateGains(pan: Float, spread: Float) -> StereoGains {
        guard spread > 0.0 else {
            return StereoGains(left: 1.0, right: 1.0)
        }
        
        // Clamp effective pan between -1.0 and +1.0
        let effectivePan = max(-1.0, min(1.0, pan * spread))
        
        // Angle in [0, pi/2]: 0 = full left, pi/4 = center, pi/2 = full right
        let angle = (effectivePan + 1.0) * (Float.pi / 4.0)
        
        // Equal power panning with center normalized to 1.0 (multiplied by sqrt(2))
        let sqrt2 = Float(1.41421356)
        let leftGain = cos(angle) * sqrt2
        let rightGain = sin(angle) * sqrt2
        
        return StereoGains(left: leftGain, right: rightGain)
    }
}
