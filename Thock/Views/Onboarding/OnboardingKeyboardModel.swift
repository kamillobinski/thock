import SwiftUI

@available(macOS 14.0, *)
@MainActor
@Observable
final class OnboardingKeyboardModel {
    static let shared = OnboardingKeyboardModel()

    struct Stroke: Identifiable, Equatable {
        let id: Int
        let label: String
    }

    static let streamLength = 9

    private(set) var pressedKeys: Set<Int64> = []
    private(set) var legend: String?
    private(set) var hasUserPressed = false
    private(set) var downTime: TimeInterval = 0
    private(set) var upTime: TimeInterval = 0
    private(set) var pulseCount = 0
    private(set) var strokes: [Stroke] = []

    @ObservationIgnored private var nextStrokeId = 0
    @ObservationIgnored private var demoTask: Task<Void, Never>?

    private init() {}

    var isPressed: Bool { !pressedKeys.isEmpty }

    func press(_ keyCode: Int64, legend: String? = nil, byUser: Bool = false) {
        guard !pressedKeys.contains(keyCode) else { return }
        if pressedKeys.isEmpty { downTime = Date().timeIntervalSinceReferenceDate }
        pressedKeys.insert(keyCode)
        pulseCount &+= 1
        let label = legend ?? Self.legend(for: keyCode)
        if !label.isEmpty {
            strokes.append(Stroke(id: nextStrokeId, label: label))
            nextStrokeId += 1
            if strokes.count > Self.streamLength { strokes.removeFirst(strokes.count - Self.streamLength) }
        }
        guard byUser else { return }
        self.legend = label
        hasUserPressed = true
    }

    func release(_ keyCode: Int64) {
        guard pressedKeys.remove(keyCode) != nil, pressedKeys.isEmpty else { return }
        upTime = Date().timeIntervalSinceReferenceDate
    }

    func releaseAll() {
        guard !pressedKeys.isEmpty else { return }
        pressedKeys.removeAll()
        upTime = Date().timeIntervalSinceReferenceDate
    }

    func clearStrokes() {
        strokes.removeAll()
    }

    func demoPress() {
        tap(17, legend: nil)
    }

    func type(_ text: String) {
        demoTask?.cancel()
        demoTask = Task { [weak self] in
            for char in text.lowercased() {
                guard let code = Self.characterCodes[char] else { continue }
                guard let self, !Task.isCancelled else { return }
                await self.stroke(code, legend: char == " " ? "space" : String(char).uppercased())
                try? await Task.sleep(for: .milliseconds(Int.random(in: 90...160)))
            }
        }
    }

    private func tap(_ code: Int64, legend: String?) {
        demoTask?.cancel()
        demoTask = Task { [weak self] in
            await self?.stroke(code, legend: legend)
        }
    }

    func cancelDemo() {
        demoTask?.cancel()
        demoTask = nil
    }

    private func stroke(_ code: Int64, legend: String?) async {
        guard !Task.isCancelled else { return }
        press(code, legend: legend)
        OnboardingAudio.shared.playKey(code, down: true, synthetic: true)
        try? await Task.sleep(for: .milliseconds(70))
        release(code)
        OnboardingAudio.shared.playKey(code, down: false, synthetic: true)
    }

    static func legend(for keyCode: Int64, characters: String? = nil) -> String {
        if let symbol = symbols[keyCode] { return symbol }
        if let characters, let scalar = characters.unicodeScalars.first,
           !CharacterSet.controlCharacters.contains(scalar), !(0xF700...0xF8FF).contains(scalar.value) {
            return characters.uppercased()
        }
        return letters[keyCode] ?? ""
    }

    private static let symbols: [Int64: String] = [
        53: "esc", 48: "⇥", 49: "space", 51: "⌫", 36: "↩", 76: "⌤", 117: "⌦",
        54: "⌘", 55: "⌘", 56: "⇧", 60: "⇧", 57: "⇪", 58: "⌥", 61: "⌥", 59: "⌃", 62: "⌃", 63: "fn",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    private static let letters: [Int64: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 50: "`",
    ]

    private static let characterCodes: [Character: Int64] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32,
        "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, " ": 49,
    ]
}
