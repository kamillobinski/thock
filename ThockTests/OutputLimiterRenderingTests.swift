import Foundation
import Testing
@testable import Thock

@Suite(.serialized)
struct OutputLimiterRenderingTests {
    @Test func productionRenderingLimitsTheSumOfOverlappingVoicesWhenEnabled() {
        withPeakLimitingPreference(true) {
            let manager = SoundManager(audioOutputEnabled: false)
            #expect(renderOverlappingVoices(manager).allSatisfy { abs($0 - 0.8875) < 0.000001 })
        }
    }

    @Test func productionRenderingPreservesFinitePeaksByDefault() {
        withPeakLimitingPreference(nil) {
            let manager = SoundManager(audioOutputEnabled: false)
            #expect(renderOverlappingVoices(manager).allSatisfy { abs($0 - 1.2) < 0.000001 })
        }
    }

    @Test func changingPeakLimitingAppliesToTheNextRenderedMix() {
        withPeakLimitingPreference(nil) {
            let manager = SoundManager(audioOutputEnabled: false)
            #expect(renderOverlappingVoices(manager).allSatisfy { abs($0 - 1.2) < 0.000001 })
            setPeakLimitingPreference(true)
            #expect(renderOverlappingVoices(manager).allSatisfy { abs($0 - 0.8875) < 0.000001 })
            setPeakLimitingPreference(false)
            #expect(renderOverlappingVoices(manager).allSatisfy { abs($0 - 1.2) < 0.000001 })
        }
    }

    @Test func bypassedRenderingStillSilencesNonfiniteSamples() {
        withPeakLimitingPreference(false) {
            let manager = SoundManager(audioOutputEnabled: false)
            let sound = SoundManager.PCMSound(data: [.nan, .infinity, -.infinity, 0.8], frameCount: 2)
            manager.enqueue(sound, pitchVariation: 0, latencyId: nil, position: nil, source: .keyboard)
            var output = [Float](repeating: 0, count: 4)
            output.withUnsafeMutableBufferPointer {
                manager.renderSamples(into: $0.baseAddress!, frameCount: 2)
            }
            #expect(output == [0, 0, 0, 0.4])
        }
    }

    private func renderOverlappingVoices(_ manager: SoundManager) -> [Float] {
        let sound = SoundManager.PCMSound(data: Array(repeating: 0.8, count: 64), frameCount: 32)
        for source: VolumeLevels.Source in [.keyboard, .keyboard, .mouse] {
            manager.enqueue(sound, pitchVariation: 0, latencyId: nil, position: nil, source: source)
        }
        var output = [Float](repeating: 0, count: 64)
        output.withUnsafeMutableBufferPointer {
            manager.renderSamples(into: $0.baseAddress!, frameCount: 32)
        }
        return output
    }

    private func setPeakLimitingPreference(_ enabled: Bool) {
        SettingsEngine.shared.setPeakLimitingEnabled(enabled)
    }

    private func withPeakLimitingPreference(_ enabled: Bool?, body: () -> Void) {
        let key = "peakLimitingEnabled"
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
            NotificationCenter.default.post(name: .peakLimitingDidChange, object: nil)
        }
        if let enabled {
            setPeakLimitingPreference(enabled)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
            NotificationCenter.default.post(name: .peakLimitingDidChange, object: nil)
        }
        body()
    }
}
