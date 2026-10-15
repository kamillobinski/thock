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
        switch source {
        case .keyboard: return master * keyboard
        case .mouse: return master * mouse
        }
    }

    static func clamped(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return max(0, min(1, value))
    }
}
