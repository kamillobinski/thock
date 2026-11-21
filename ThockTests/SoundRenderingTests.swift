import Foundation
import Testing
@testable import Thock

struct SoundRenderingTests {
    @Test func recoveryDetachesTheNewestVoiceBeforeTeardownCallbacksRender() throws {
        let manager = SoundManager(audioOutputEnabled: false)
        let older = SoundManager.PCMSound(data: Array(repeating: 0.8, count: 1024), frameCount: 512)
        let newest = SoundManager.PCMSound(data: Array(repeating: -0.4, count: 8), frameCount: 4)
        let position = SoundPosition(azimuth: 30, elevation: -10)
        let latencyID = UUID()
        manager.enqueue(older, pitchVariation: 0, latencyId: nil, position: nil, source: .keyboard)
        manager.enqueue(newest, pitchVariation: 0, latencyId: latencyID, position: position,
                        source: .mouse, playbackRate: 1.25)

        var output = [Float](repeating: 0, count: 64)
        let retained = try #require(manager.stopPlayback(preservingLatestSound: true) {
            // Model render callbacks that still run while the output stops. A late
            // snapshot would consume the short newest voice and retain the older one.
            for _ in 0..<3 {
                output.withUnsafeMutableBufferPointer {
                    manager.renderSamples(into: $0.baseAddress!, frameCount: 32)
                }
                #expect(output.allSatisfy { $0 == 0 }, "Teardown callbacks must not render pending voices")
            }
        })
        #expect(retained.sound === newest)
        #expect(retained.rate == 1.25)
        #expect(retained.source == .mouse)
        #expect(retained.position == position)
        #expect(retained.latencyId == latencyID)
        #expect(retained.sourcePosition == 0)
    }

    @Test func rendersIOCyclesLargerThanTheConfiguredBuffer() {
        let manager = SoundManager(audioOutputEnabled: false)
        // Every frame and channel differs, so a repeated block or swapped channels would show
        let samples = (0..<3000).flatMap { frame -> [Float] in
            let left = 0.1 + Float(frame) * 0.0002
            return [left, -left / 2]
        }
        let sound = SoundManager.PCMSound(data: samples, frameCount: 3000)
        manager.enqueue(sound, pitchVariation: 0, latencyId: nil, position: nil, source: .keyboard)

        // More frames than the largest buffer setting, so the cycle spans several render blocks
        let frames = 4096
        var output = [Float](repeating: 0, count: frames * 2)
        output.withUnsafeMutableBufferPointer {
            manager.fillOutput($0.baseAddress!, frameCount: frames)
        }

        let gain = output[0] / samples[0]
        #expect(gain > 0)
        for (index, sample) in samples.enumerated() {
            #expect(abs(output[index] - sample * gain) < 0.0001, "The sound continues across block boundaries")
        }
        #expect(output.dropFirst(samples.count).allSatisfy { $0 == 0 })
    }
}
