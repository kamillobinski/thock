//
//  KeyMapper.swift
//  Thock
//
//  Created by Kamil Łobiński on 13/03/2025.
//

/// A utility struct that maps macOS hardware key codes to string representations.
/// Provides a way to convert key codes into human-readable key names.
struct KeyMapper {
    
    /// The default key name used when a key code is not found in the mapping.
    static let keyCodeNotFound: String = "default"
    
    private static let keyCodeMap: [Int64: String] = [
        // NUMBERS
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
        28: "8", 25: "9", 29: "0",
        
        // NUMPAD
        83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7",
        91: "8", 92: "9", 82: "0", 67: "*", 75: "/", 69: "+", 78: "-",
        81: "=", 65: ".", 71: "clear",
        
        // LETTERS
        12: "q", 13: "w", 14: "e", 15: "r", 17: "t", 16: "y", 32: "u",
        34: "i", 31: "o", 35: "p", 0: "a", 1: "s", 2: "d", 3: "f",
        5: "g", 4: "h", 38: "j", 40: "k", 37: "l", 6: "z", 7: "x",
        8: "c", 9: "v", 11: "b", 45: "n", 46: "m",
        
        // SYMBOLS
        24: "=", 27: "-", 33: "[", 30: "]", 41: ";", 39: "'", 43: ",",
        47: ".", 44: "/", 42: "\\", 50: "`",
        
        // MODIFIERS
        48: "tab", 49: "space", 51: "del", 53: "esc", 57: "capsLock",
        59: "ctrlLeft", 63: "fn",
        36: "enter", 76: "enter",
        54: "command", 55: "command",
        56: "shiftLeft", 60: "shiftRight",
        58: "optionLeft", 61: "optionRight",
        
        // NAVIGATION
        123: "arrLeft", 124: "arrRight", 125: "arrDown", 126: "arrUp",
        115: "home", 119: "end", 116: "pgUp", 121: "pgDn",
        
        // FUNCTION
        122: "f1", 120: "f2", 99: "f3", 118: "f4", 96: "f5", 97: "f6",
        98: "f7", 100: "f8", 101: "f9", 109: "f10", 103: "f11", 111: "f12",
    ]
    
    static func fromKeyCode(_ keyCode: Int64) -> String {
        return keyCodeMap[keyCode] ?? keyCodeNotFound
    }
}
