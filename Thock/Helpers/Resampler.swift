import Accelerate

/// Cubic-interpolation playback of PCM at an arbitrary rate, keeping fractional phase between calls.
enum Resampler {
    /// Catmull-Rom curve through four consecutive samples, evaluated between the middle two
    @inline(__always)
    private static func interpolate(_ before: Float, _ from: Float, _ to: Float, _ after: Float, fraction: Float) -> Float {
        let c1 = 0.5 * (to - before)
        let c2 = before - 2.5 * from + 2 * to - 0.5 * after
        let c3 = 0.5 * (after - before) + 1.5 * (from - to)
        return ((c3 * fraction + c2) * fraction + c1) * fraction + from
    }

    @discardableResult
    static func mix(source: UnsafeBufferPointer<Float>, channels: Int, frameCount: Int,
                    position: inout Double, rate: Double,
                    into out: UnsafeMutablePointer<Float>, outChannels: Int, outFrames: Int,
                    gains: (left: Float, right: Float)) -> Int {
        guard let base = source.baseAddress, frameCount > 0, position < Double(frameCount) else { return 0 }

        // Unity rate on a whole frame, plain scaled copy
        if rate == 1, position == position.rounded(.down) {
            let start = Int(position)
            let count = min(outFrames, frameCount - start)
            var left = gains.left
            var right = gains.right
            let src = base + start * channels
            if outChannels == 1 {
                vDSP_vsma(src, vDSP_Stride(channels), &left, out, 1, out, 1, vDSP_Length(count))
            } else {
                let rightSrc = channels == 2 ? src + 1 : src
                vDSP_vsma(src, vDSP_Stride(channels), &left, out, 2, out, 2, vDSP_Length(count))
                vDSP_vsma(rightSrc, vDSP_Stride(channels), &right, out + 1, 2, out + 1, 2, vDSP_Length(count))
            }
            position += Double(count)
            return count
        }

        let last = frameCount - 1
        let rightOffset = channels == 2 ? 1 : 0
        var pos = position
        var written = 0
        while written < outFrames {
            let frame = Int(pos)
            if frame >= frameCount { break }
            let fraction = Float(pos - Double(frame))
            // The first and last frames stand in for the neighbours they lack
            let before = max(frame - 1, 0) * channels
            let a = frame * channels
            let b = min(frame + 1, last) * channels
            let after = min(frame + 2, last) * channels

            let leftSample = interpolate(base[before], base[a], base[b], base[after], fraction: fraction)
            if outChannels == 1 {
                out[written] += leftSample * gains.left
            } else {
                let rightSample = interpolate(base[before + rightOffset], base[a + rightOffset],
                                              base[b + rightOffset], base[after + rightOffset], fraction: fraction)
                out[written * 2] += leftSample * gains.left
                out[written * 2 + 1] += rightSample * gains.right
            }
            pos += rate
            written += 1
        }
        position = pos
        return written
    }
}
