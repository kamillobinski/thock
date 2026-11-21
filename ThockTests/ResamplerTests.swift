import Foundation
import Testing
@testable import Thock

struct ResamplerTests {
    /// Plays a mono source into a mono buffer and returns what was written
    private func resample(_ source: [Float], rate: Double, frames: Int) -> [Float] {
        var output = [Float](repeating: 0, count: frames)
        var position = 0.0
        let written = source.withUnsafeBufferPointer { pcm in
            output.withUnsafeMutableBufferPointer { out in
                Resampler.mix(source: pcm, channels: 1, frameCount: source.count, position: &position, rate: rate,
                              into: out.baseAddress!, outChannels: 1, outFrames: frames, gains: (1, 1))
            }
        }
        return Array(output.prefix(written))
    }

    @Test func followsAToneCloselyWhenConvertingSampleRates() {
        // A tone with an 8 sample period is 5.5 kHz at 44.1 kHz, played here at the 44.1 to 48 kHz ratio.
        // Linear interpolation is off by up to 7% of full scale on it.
        let period = 8.0
        let rate = 44100.0 / 48000.0
        let source = (0..<400).map { Float(sin(2 * Double.pi * Double($0) / period)) }
        let output = resample(source, rate: rate, frames: 400)

        for (index, sample) in output.enumerated().dropFirst(8).dropLast(8) {
            let expected = Float(sin(2 * Double.pi * Double(index) * rate / period))
            #expect(abs(sample - expected) < 0.01)
        }
    }

    @Test func reproducesARampExactly() {
        let source = (0..<32).map(Float.init)
        let output = resample(source, rate: 0.5, frames: 40)

        for (index, sample) in output.enumerated().dropFirst(2) {
            #expect(abs(sample - Float(index) * 0.5) < 0.0001)
        }
    }

    @Test func stopsAtTheEndOfTheSource() {
        let output = resample([1, 1, 1, 1], rate: 0.5, frames: 32)
        #expect(output.count == 8)
        #expect(output.allSatisfy { abs($0 - 1) < 0.0001 })
    }
}
