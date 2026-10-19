import Foundation
import Testing
@testable import Thock

struct SoundRenderingTests {
    @Test func productionRenderingLimitsTheSumOfOverlappingVoices() {
        let manager = SoundManager(audioOutputEnabled: false)
        let sound = SoundManager.PCMSound(data: Array(repeating: 0.8, count: 64), frameCount: 32)
        for _ in 0..<3 {
            manager.enqueue(sound, pitchVariation: 0, latencyId: nil, position: nil, source: .keyboard)
        }
        var output = [Float](repeating: 0, count: 64)
        output.withUnsafeMutableBufferPointer {
            manager.renderSamples(into: $0.baseAddress!, frameCount: 32)
        }
        // Three 0.8 voices at the offline mixer's default 0.5 gain sum to 1.2.
        // The production output must include the final limiter, whose result is 0.8875.
        #expect(output.allSatisfy { $0.isFinite && abs($0 - 0.8875) < 0.000001 })
    }

}
