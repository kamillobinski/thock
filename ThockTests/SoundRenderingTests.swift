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
            // Model pending buffers returned by synchronous AudioQueueStop. A late
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
