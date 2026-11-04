import Foundation
import SwiftUI

/// Holds which keys are currently highlighted in the key overlay.
/// A pressed key stays lit while held; after release it keeps a short
/// "flash" so quick taps remain visible.
final class KeyOverlayModel: ObservableObject {
    /// How long a key stays lit after being released (seconds).
    static let flashDuration: TimeInterval = 0.15

    @Published private(set) var pressedKeys: Set<Int64> = []
    @Published private(set) var flashingKeys: Set<Int64> = []
    @Published var scale: Double = 1.0
    @Published var theme: String = "dark"
    /// Panel opacity (0.2...1.0); the keyboard background goes fully
    /// solid at 1.0 and stays translucent below.
    @Published var opacity: Double = 1.0

    private var flashTimers: [Int64: DispatchWorkItem] = [:]

    func keyDown(_ keyCode: Int64) {
        flashTimers[keyCode]?.cancel()
        flashTimers[keyCode] = nil
        flashingKeys.remove(keyCode)
        pressedKeys.insert(keyCode)
    }

    func keyUp(_ keyCode: Int64) {
        pressedKeys.remove(keyCode)
        flashingKeys.insert(keyCode)
        let work = DispatchWorkItem { [weak self] in
            self?.flashingKeys.remove(keyCode)
            self?.flashTimers[keyCode] = nil
        }
        flashTimers[keyCode] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.flashDuration, execute: work)
    }

    func isActive(_ keyCode: Int64) -> Bool {
        pressedKeys.contains(keyCode) || flashingKeys.contains(keyCode)
    }

    func reset() {
        flashTimers.values.forEach { $0.cancel() }
        flashTimers.removeAll()
        pressedKeys.removeAll()
        flashingKeys.removeAll()
    }
}
