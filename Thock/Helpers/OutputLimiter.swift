/// Bounds the final mixed PCM block without adding buffering or lookahead latency.
/// Adapted from Rafael Lozano's soft-clipping curve in PR #149.
enum OutputLimiter {
    /// Samples up to 0.7 pass through; louder finite samples approach full scale
    /// smoothly. This waveshaping can change the timbre of loud sounds.
    static func apply(to buffer: UnsafeMutablePointer<Float>, sampleCount: Int) {
        let threshold: Float = 0.7
        let headroom = 1 - threshold

        for index in 0..<sampleCount {
            let sample = buffer[index]
            guard sample.isFinite else {
                buffer[index] = 0
                continue
            }
            let magnitude = abs(sample)
            guard magnitude > threshold else { continue }

            let excess = magnitude - threshold
            let limited = threshold + headroom * (excess / (excess + headroom))
            buffer[index] = sample < 0 ? -limited : limited
        }
    }
}
