import AVFoundation
import Testing
@testable import Thock

struct LeadingSilenceTests {
    private func makeBuffer(_ channels: [[Float]]) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: AVAudioChannelCount(channels.count))!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(channels[0].count))!
        buffer.frameLength = buffer.frameCapacity
        for (index, samples) in channels.enumerated() {
            samples.withUnsafeBufferPointer {
                buffer.floatChannelData![index].update(from: $0.baseAddress!, count: samples.count)
            }
        }
        return buffer
    }

    private func samples(of buffer: AVAudioPCMBuffer, channel: Int) -> [Float] {
        Array(UnsafeBufferPointer(start: buffer.floatChannelData![channel], count: Int(buffer.frameLength)))
    }

    @Test func dropsFramesBeforeTheAttack() {
        // Two silent frames and a frame of noise below the threshold, then the attack starts in the right channel
        let buffer = makeBuffer([[0, 0, 0.001, 0, 1, 0.5],
                                 [0, 0, -0.001, 0.5, 1, 0.5]])
        LeadingSilence.trim(buffer)
        #expect(samples(of: buffer, channel: 0) == [0, 1, 0.5])
        #expect(samples(of: buffer, channel: 1) == [0.5, 1, 0.5])
    }

    @Test func keepsSoundsThatStartImmediately() {
        let buffer = makeBuffer([[0.9, 0.1, 0]])
        LeadingSilence.trim(buffer)
        #expect(samples(of: buffer, channel: 0) == [0.9, 0.1, 0])
    }

    @Test func leavesSilentSoundsAlone() {
        let buffer = makeBuffer([[0, 0, 0, 0]])
        LeadingSilence.trim(buffer)
        #expect(buffer.frameLength == 4)
    }
}
