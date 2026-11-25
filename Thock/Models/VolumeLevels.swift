import Foundation

/// A snapshot of the master volume and the relative level of each sound source.
struct VolumeLevels {
    enum Source {
        case keyboard
        case mouse
    }

    let master: Float
    var keyboard: Float = 1
    var mouse: Float = 1

    func gain(for source: Source) -> Float {
        master * sourceGain(for: source)
    }

    /// Relative gain applied before spatial mixing; master scales the shared output.
    func sourceGain(for source: Source) -> Float {
        switch source {
        case .keyboard: return keyboard
        case .mouse: return mouse
        }
    }

    /// Compensate the shared master gain so dry and spatial paths retain their source levels.
    func compensatingForSystemVolume(_ volume: Float) -> Self {
        let master = min(master / pow(max(volume, 0.01), 1.08), 2)
        return Self(master: master, keyboard: keyboard, mouse: mouse)
    }

    static func clamped(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return max(0, min(1, value))
    }
}
