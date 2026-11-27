import AVFoundation
import Accelerate

/// Drops the dead air a recording carries before its attack, so a sound starts when its key does.
enum LeadingSilence {
    /// Samples quieter than this fraction of the sound's peak count as silence (-40 dB)
    static let threshold: Float = 0.01

    /// Removes the leading silence from a buffer in place. Silent and empty buffers are left alone.
    static func trim(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var peak: Float = 0
        for channel in 0..<channelCount {
            var channelPeak: Float = 0
            vDSP_maxmgv(channels[channel], 1, &channelPeak, vDSP_Length(frameCount))
            peak = max(peak, channelPeak)
        }
        let floor = peak * threshold
        guard floor > 0 else { return }

        // The sound starts at the first frame where any channel rises above the floor
        let start = (0..<channelCount).compactMap { channel in
            (0..<frameCount).first { abs(channels[channel][$0]) >= floor }
        }.min() ?? 0
        guard start > 0 else { return }

        for channel in 0..<channelCount {
            memmove(channels[channel], channels[channel] + start, (frameCount - start) * MemoryLayout<Float>.size)
        }
        buffer.frameLength = AVAudioFrameCount(frameCount - start)
    }
}
